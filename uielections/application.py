from collections import namedtuple

from flask import Flask, Blueprint, jsonify, url_for, request, render_template
from sqlalchemy_utils import escape_like
from sqlalchemy import or_, func, Date
from flask_sqlalchemy import SQLAlchemy

from .datatables import DataTable

FieldColumn = namedtuple('FieldColumn', 'name,title,filter,type,orderable,searchable,visible,editable,choices')
noop_filter = lambda instance, value: value


def getname_filter(model, field):
    return lambda instance, value: getattr(model.query.get(value), field)


app = Flask(__name__)
app.config.from_object('uielections.config')
app.config.from_envvar('UIELECTIONS_CONFIG', silent=True)

db = SQLAlchemy(app=app)

dt = Blueprint('datatables', __name__)
TABLES = {}


def mynamedtuple(name, *field_args):
    nt = namedtuple(name, *field_args)

    class MyNamedTuple(nt):
        def __str__(self):
            return '_'.join(map(str, self))

    MyNamedTuple.__name__ = name
    return MyNamedTuple


class Constituency(db.Model):
    __tablename__ = 'consituencies'  # TODO typo

    FIELDS = [
        FieldColumn('id', 'ID', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=False, editable=False),
        FieldColumn('name', 'Name', noop_filter, 'string', orderable=True, searchable=True, choices=None, visible=True, editable=True),
    ]

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Unicode, nullable=False)


class District(db.Model):
    __tablename__ = 'districts'

    FIELDS = [
        FieldColumn('id', 'ID', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=False, editable=False),
        FieldColumn('name', 'Name', noop_filter, 'string', orderable=True, searchable=True, choices=None, visible=True, editable=True),
        FieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency, visible=True, editable=False),
    ]

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Unicode, nullable=False)
    constituency_id = db.Column(db.Integer, nullable=False)


class CandidateCategory(db.Model):
    __tablename__ = 'candidate_categories'

    FIELDS = [
        FieldColumn('id', 'ID', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=False, editable=False),
        FieldColumn('name', 'Name', noop_filter, 'string', orderable=True, searchable=True, choices=None, visible=True, editable=True),
    ]

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Unicode, nullable=False)


class DistrictQuota(db.Model):
    __tablename__ = 'district_quotas'

    _DistrictQuotaId = mynamedtuple('DistrictQuotaId', 'district_id,category_id')

    FIELDS = [
        FieldColumn('district_id', 'District', getname_filter(District, 'name'), 'string', orderable=True, searchable=True, choices=District, visible=True, editable=False),
        FieldColumn('category_id', 'Category', getname_filter(CandidateCategory, 'name'), 'string', orderable=True, searchable=True, choices=CandidateCategory, visible=True, editable=False),
        FieldColumn('value', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=True, editable=True),
    ]

    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'), primary_key=True)
    category_id = db.Column(db.Integer, db.ForeignKey('candidate_categories.id'), primary_key=True)
    value = db.Column(db.Integer, nullable=False)

    id = db.CompositeProperty(_DistrictQuotaId, 'district_id', 'category_id')


class ElectoralList(db.Model):
    __tablename__ = 'electoral_lists'

    FIELDS = [
        FieldColumn('id', 'ID', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=False, editable=False),
        FieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency, visible=True, editable=False),
        FieldColumn('name', 'Name', noop_filter, 'string', orderable=True, searchable=True, choices=None, visible=True, editable=True),
    ]

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Unicode, nullable=False)
    constituency_id = db.Column(db.Integer, db.ForeignKey('consituencies.id'), nullable=False)


class Candidate(db.Model):
    __tablename__ = 'candidates'

    FIELDS = [
        FieldColumn('id', 'ID', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=False, editable=False),
        FieldColumn('name', 'Name', noop_filter, 'string', orderable=True, searchable=True, choices=None, visible=True, editable=True),
        FieldColumn('district_id', 'District', getname_filter(District, 'name'), 'string', orderable=True, searchable=True, choices=District, visible=True, editable=False),
        FieldColumn('electoral_list_id', 'List', getname_filter(ElectoralList, 'name'), 'string', orderable=True, searchable=True, choices=ElectoralList, visible=True, editable=False),
        FieldColumn('category_id', 'Category', getname_filter(CandidateCategory, 'name'), 'string', orderable=True, searchable=True, choices=CandidateCategory, visible=True, editable=False),
    ]

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Unicode, nullable=False)
    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'))
    electoral_list_id = db.Column(db.Integer, db.ForeignKey('electoral_lists.id'))
    category_id = db.Column(db.Integer, db.ForeignKey('candidate_categories.id'))


class VotesPerList(db.Model):
    __tablename__ = 'votes_per_list'
    __table_args__ = (
        db.UniqueConstraint('constituency_id', 'electoral_list_id'),
    )

    _ListVotesId = mynamedtuple('ListVotesId', 'constituency_id,electoral_list_id')

    FIELDS = [
        FieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency, visible=True, editable=False),
        FieldColumn('electoral_list_id', 'List', getname_filter(ElectoralList, 'name'), 'string', orderable=True, searchable=True, choices=ElectoralList, visible=True, editable=False),
        FieldColumn('value', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=True, editable=True),
    ]

    constituency_id = db.Column(db.Integer, db.ForeignKey('consituencies.id'), primary_key=True)
    electoral_list_id = db.Column(db.Integer, db.ForeignKey('electoral_lists.id'), primary_key=True)  # TODO handle blanks!
    value = db.Column(db.Integer, nullable=False)

    id = db.CompositeProperty(_ListVotesId, 'constituency_id', 'electoral_list_id')


class PreferentialVote(db.Model):
    __tablename__ = 'preferential_votes'

    FIELDS = [
        FieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency, visible=True, editable=False),
        FieldColumn('candidate_id', 'Candidate', getname_filter(Candidate, 'name'), 'string', orderable=True, searchable=True, choices=Candidate, visible=True, editable=False),
        FieldColumn('value', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None, visible=True, editable=True),
    ]

    _PreferentialVoteId = mynamedtuple('_PreferentialVoteId', 'constituency_id,candidate_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('consituencies.id'), primary_key=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'), primary_key=True)
    value = db.Column(db.Integer, nullable=False)

    id = db.CompositeProperty(_PreferentialVoteId, 'constituency_id', 'candidate_id')


@app.route('/')
def index():
    tables = {k: v() for k, v in TABLES.items()}
    return render_template('index.html', tables=tables)


def datatables_meta(fields, route):
    return {
        "datatables": {
            "columns": [
                {
                    'data': f.name,
                    'name': f.name,
                    'title': f.title or u'',
                    'orderable': f.orderable,
                    '_type': f.type,
                    'defaultContent': '<small><span class="label label-default">N/A</span></small>',
                }
                for f in fields
            ],
            "processing": True,
            "serverSide": True,
            "ajax": url_for('.ajax_list_{}'.format(route), _external=True),
        },
        "create": {
            "fields": [
                {
                    'name': f.name,
                    'title': f.title or u'',
                    'type': f.type,
                    'visible': f.visible,
                    'editable': f.editable,
                    'choices': [{
                            'id': c.id,
                            'name': c.name,
                        }
                        for c in f.choices.query
                    ] if f.choices else None,
                }
                for f in fields
            ],
            "ajax": url_for('.ajax_create_{}'.format(route), _external=True)
        }
    }


def datatables_list(model, fields, route):
    query = db.session.query(model)

    table = DataTable(request.args, model, query, [
        (f.name, f.name, f.filter)
        for f in fields
    ])

    def search(queryset, user_input):
        if user_input is None or user_input == u'':
            return None
        queryset = queryset.filter(or_(*(
            getattr(model, f.name).ilike(u'%{}%'.format(escape_like(str(user_input))))
            for f in fields
            if f.searchable
        )))
        return queryset
    table.searchable(search)
    table.add_data(edit_ajax=lambda o: url_for(".ajax_edit_{}".format(route), mid=o.id, _external=True))
    table.add_data(delete_ajax=lambda o: url_for(".ajax_delete_{}".format(route), mid=o.id, _external=True))
    table.add_data(fields_data=lambda o: {f.name: getattr(o, f.name) for f in fields})

    return table.json()


def datatables_edit(model, mid, fields, body, route):
    instance = model.query.get_or_404(mid.split('_'))

    for f in fields:
        if f.visible and f.name not in body:
            continue
        value = body[f.name]
        setattr(instance, f.name, value)

    db.session.commit()

    return {
        'message_severity': 'error',
        'message': 'All good.',
        'errors': {},
        'success': True,
    }


def datatables_delete(model, mid, route):
    instance = model.query.get_or_404(mid.split('_'))
    db.session.delete(instance)
    db.session.commit()

    return {
        'message_severity': 'error',
        'message': 'All good.',
        'errors': {},
        'success': True,
    }


def datatables_create(model, fields, body, route):
    instance = model()
    db.session.add(instance)

    for f in fields:
        if not f.visible or f.name not in body:
            continue
        value = body[f.name]
        setattr(instance, f.name, value)

    db.session.commit()

    return {
        'message_severity': 'error',
        'message': 'All good.',
        'errors': {},
        'success': True,
    }


def potato(dt, _model):
    _route_name = _model.__name__.lower()

    @dt.route('/{}/meta'.format(_route_name), endpoint='meta_{}'.format(_route_name))
    def meta_constituency():
        return jsonify(datatables_meta(_model.FIELDS, _route_name))

    @dt.route('/{}/ajax/list'.format(_route_name), endpoint='ajax_list_{}'.format(_route_name))
    def ajax_list_constituency():
        return jsonify(datatables_list(_model, _model.FIELDS, _route_name))

    @dt.route('/{}/ajax/create'.format(_route_name), endpoint='ajax_create_{}'.format(_route_name), methods=['POST'])
    def ajax_create_constituency():
        return jsonify(datatables_create(_model, _model.FIELDS, request.form, _route_name))

    @dt.route('/{}/ajax/edit/<mid>'.format(_route_name), endpoint='ajax_edit_{}'.format(_route_name), methods=['POST'])
    def ajax_edit_constituency(mid):
        return jsonify(datatables_edit(_model, mid, _model.FIELDS, request.form, _route_name))

    @dt.route('/{}/ajax/delete/<mid>'.format(_route_name), endpoint='ajax_delete_{}'.format(_route_name), methods=['POST'])
    def ajax_delete_constituency(mid):
        return jsonify(datatables_delete(_model, mid, _route_name))

    TABLES[_route_name] = lambda rn=_route_name: url_for('datatables.meta_{}'.format(rn), _external=True)


potato(dt, Constituency)
potato(dt, District)
potato(dt, CandidateCategory)
potato(dt, DistrictQuota)
potato(dt, ElectoralList)
potato(dt, Candidate)
potato(dt, VotesPerList)
potato(dt, PreferentialVote)

app.register_blueprint(dt)