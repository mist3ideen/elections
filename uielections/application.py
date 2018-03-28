from collections import namedtuple
import calendar
from datetime import datetime
from decimal import Decimal, localcontext

from flask import Flask, Blueprint, jsonify, url_for, request, render_template, g, current_app
from flask.json import JSONEncoder
from sqlalchemy_utils import escape_like
from sqlalchemy import or_, func, Date
from flask_sqlalchemy import SQLAlchemy
from hashids import Hashids
import random
import string

from .datatables import DataTable

FieldColumn = namedtuple('FieldColumn', 'name,title,filter,type,orderable,searchable,visible,editable,choices')
ROFieldColumn = lambda *args, **kwargs: FieldColumn(*args, editable=False, visible=False, **kwargs)
noop_filter = lambda instance, value: value


TEMPLATE_NAMES = (
    'ar_dummy',
    'en_dummy',
    'ar_clean',
    'en_clean',
    'empty',
    'ar_real_data_20180328',
)


def getname_filter(model, field):
    return lambda instance, value: getattr(model.query.get(value), field)


def create_hashid(intid):
    hashids = Hashids(min_length=current_app.config['HASHIDS_MIN_LENGTH'], salt=current_app.config['HASHIDS_SECRET_KEY'])
    hashid = hashids.encode(intid, current_app.config['HASHIDS_CANARY'])
    return hashid


def decode_hashid(hashid):
    hashids = Hashids(min_length=current_app.config['HASHIDS_MIN_LENGTH'], salt=current_app.config['HASHIDS_SECRET_KEY'])
    intid, canary = hashids.decode(hashid)
    assert canary == current_app.config['HASHIDS_CANARY']
    return intid


class CustomJSONEncoder(JSONEncoder):

    def default(self, obj):
        if isinstance(obj, datetime):
            if obj.utcoffset() is not None:
                obj = obj - obj.utcoffset()
            millis = int(
                calendar.timegm(obj.timetuple()) * 1000 +
                obj.microsecond / 1000
            )
            return millis
        elif isinstance(obj, Decimal):
            # return str(obj)
            # return float(obj)
            # with localcontext() as ctx:
            #     ctx.prec = 4
            return str(obj.quantize(Decimal('1.0000')))
        try:
            iterable = iter(obj)
        except TypeError:
            pass
        else:
            return list(iterable)
        return JSONEncoder.default(self, obj)


app = Flask(__name__)
app.json_encoder = CustomJSONEncoder
app.config.from_object('uielections.config')
app.config.from_envvar('UIELECTIONS_CONFIG', silent=True)

db = SQLAlchemy(app=app)

dt = Blueprint('datatables', __name__, url_prefix='/simulation/<simulation>')
TABLES = {}


class View:
    pass


def mynamedtuple(name, *field_args):
    nt = namedtuple(name, *field_args)

    class MyNamedTuple(nt):
        def __str__(self):
            return '_'.join(map(str, self))

    MyNamedTuple.__name__ = name
    return MyNamedTuple


class Simulation(db.Model):
    __tablename__ = 'simulations'
    __table_args__ = {'schema': 'simulation'}

    id = db.Column(db.Integer, primary_key=True)
    schema_name_seed = db.Column('schema_name', db.String, nullable=False)

    @property
    def schema_name(self):
        return 'sim_{}_{}'.format(self.id, self.schema_name_seed)


class Constituency(db.Model):
    __tablename__ = 'constituencies'

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
    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), nullable=False)


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

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
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

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'), primary_key=True)
    value = db.Column(db.Integer, nullable=False)

    id = db.CompositeProperty(_PreferentialVoteId, 'constituency_id', 'candidate_id')


class ConstituencyListSize(View, db.Model):
    __tablename__ = 'constituency_list_size'

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('list_size', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.synonym('constituency_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    list_size = db.Column(db.Integer, nullable=False)


class ConstituencyTotalVotes(View, db.Model):
    __tablename__ = 'constituency_total_votes'

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('total_votes', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.synonym('constituency_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    total_votes = db.Column(db.Integer, nullable=False)


class ConstituencyInitialThreshold(View, db.Model):
    __tablename__ = 'results_constituency_threshold'

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('list_threshold', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.synonym('constituency_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    list_threshold = db.Column(db.Integer, nullable=False)


class ConstituencyCountedVotes(View, db.Model):
    __tablename__ = 'results_constituency_total_votes'

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('total_votes', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.synonym('constituency_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    total_votes = db.Column(db.Integer, nullable=False)


def _allocated_seats_filter(o, v):
    return '{ss}{v:.5} / {t}{es}'.format(
        v=v, t=o.list_size,
        ss='<s>' if not o.passed_threshold else '', es='</s>' if not o.passed_threshold else ''
    )


def _updated_votes_filter(o, v):
    return v if o.passed_threshold else '<s>{:.5}</s>'.format(v)


class ListAllocations(View, db.Model):
    __tablename__ = 'results_list_allocations'

    _ListAllocationsId = mynamedtuple('_ListAllocationsId', 'constituency_id,electoral_list_id')

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('electoral_list_id', 'List', getname_filter(ElectoralList, 'name'), 'string', orderable=True, searchable=True, choices=ElectoralList),
        ROFieldColumn('value', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None),
        ROFieldColumn('passed_threshold', '> Threshold?', noop_filter, 'number', orderable=True, searchable=False, choices=None),
        ROFieldColumn('votes_percentage_pre', 'Initial Votes (%)', noop_filter, 'number', orderable=True, searchable=False, choices=None),
        ROFieldColumn('votes_percentage_post', 'Updated Votes (%)', _updated_votes_filter, 'number', orderable=True, searchable=False, choices=None),
        ROFieldColumn('allocated_seats', 'Allocated Seats', _allocated_seats_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.CompositeProperty(_ListAllocationsId, 'constituency_id', 'electoral_list_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    electoral_list_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    value = db.Column(db.Integer, nullable=False)
    votes_percentage_pre = db.Column(db.Numeric, nullable=False)
    passed_threshold = db.Column(db.Boolean, nullable=False)
    votes_percentage_post = db.Column(db.Numeric, nullable=False)
    allocated_seats = db.Column(db.Numeric, nullable=False)
    list_size = db.Column(db.Integer, nullable=False)


class AdjustedListAllocations(View, db.Model):
    __tablename__ = 'results_adjusted_list_allocations'

    _ListAllocationsId = mynamedtuple('_ListAllocationsId', 'constituency_id,electoral_list_id')

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('electoral_list_id', 'List', getname_filter(ElectoralList, 'name'), 'string', orderable=True, searchable=True, choices=ElectoralList),
        ROFieldColumn('allocated_seats', 'Seats', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.CompositeProperty(_ListAllocationsId, 'constituency_id', 'electoral_list_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    electoral_list_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'), primary_key=True)
    # allocated_seats = db.Column('sum', db.Integer, nullable=False)
    allocated_seats = db.Column(db.Integer, nullable=False)


class TotalPreferentialVotes(View, db.Model):
    __tablename__ = 'results_total_preferential_votes'

    FIELDS = [
        ROFieldColumn('district_id', 'District', getname_filter(District, 'name'), 'string', orderable=True, searchable=True, choices=District),
        ROFieldColumn('total_votes', 'Value', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.synonym('district_id')

    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'), primary_key=True)
    total_votes = db.Column(db.Integer, nullable=False)


class SortedPreferentialList(View, db.Model):
    __tablename__ = 'results_sorted_preferential_list'

    # rowno, constituency_id, district_id, candidate_id, category_id, electoral_list_id, district_category_quota, allocated_seats, preferential_percentage
    _SortedPreferentialId = mynamedtuple('_SortedPreferentialId', 'rowno,constituency_id')

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('rowno', 'Rank', noop_filter, 'number', orderable=True, searchable=True, choices=None),
        ROFieldColumn('electoral_list_id', 'List', getname_filter(ElectoralList, 'name'), 'string', orderable=True, searchable=True, choices=ElectoralList),
        ROFieldColumn('district_id', 'District', getname_filter(District, 'name'), 'string', orderable=True, searchable=True, choices=District),
        ROFieldColumn('category_id', 'Category', getname_filter(CandidateCategory, 'name'), 'string', orderable=True, searchable=True, choices=CandidateCategory),
        ROFieldColumn('candidate_id', 'Candidate', getname_filter(Candidate, 'name'), 'string', orderable=True, searchable=True, choices=Candidate),
        ROFieldColumn('district_category_quota', 'D/C Quota', noop_filter, 'number', orderable=True, searchable=True, choices=None),
        ROFieldColumn('allocated_seats', 'Seats', noop_filter, 'number', orderable=True, searchable=True, choices=None),
        ROFieldColumn('preferential_percentage', 'Value (%)', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.CompositeProperty(_SortedPreferentialId, 'rowno', 'constituency_id')

    rowno = db.Column(db.Integer, primary_key=True)
    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'))
    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'))
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'))
    category_id = db.Column(db.Integer, db.ForeignKey('candidate_categories.id'))
    electoral_list_id = db.Column(db.Integer, db.ForeignKey('electoral_lists.id'))
    district_category_quota = db.Column(db.Integer)
    allocated_seats = db.Column(db.Integer)
    preferential_percentage = db.Column(db.Numeric)


def _illustrated_filter(f=noop_filter):
    return lambda o, v: '{ss}{v}{es}'.format(
        v=f(o, v),
        ss='<strong>' if o.winning else '<s>', es='</strong>' if not o.winning else '</s>'
    )


class IllustratedFinalResult(View, db.Model):
    __tablename__ = 'results_preferential_illustrated'

    _SortedPreferentialId = mynamedtuple('_SortedPreferentialId', 'rowno,constituency_id')

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', _illustrated_filter(getname_filter(Constituency, 'name')), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('rowno', 'Rank', _illustrated_filter(), 'number', orderable=True, searchable=True, choices=None),
        ROFieldColumn('electoral_list_id', 'List', _illustrated_filter(getname_filter(ElectoralList, 'name')), 'string', orderable=True, searchable=True, choices=ElectoralList),
        ROFieldColumn('district_id', 'District', _illustrated_filter(getname_filter(District, 'name')), 'string', orderable=True, searchable=True, choices=District),
        ROFieldColumn('category_id', 'Category', _illustrated_filter(getname_filter(CandidateCategory, 'name')), 'string', orderable=True, searchable=True, choices=CandidateCategory),
        ROFieldColumn('candidate_id', 'Candidate', _illustrated_filter(getname_filter(Candidate, 'name')), 'string', orderable=True, searchable=True, choices=Candidate),
        ROFieldColumn('district_category_quota', 'D/C Quota', _illustrated_filter(), 'number', orderable=True, searchable=True, choices=None),
        ROFieldColumn('allocated_seats', 'Seats', _illustrated_filter(), 'number', orderable=True, searchable=True, choices=None),
        ROFieldColumn('preferential_percentage', 'Value (%)', _illustrated_filter(), 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.CompositeProperty(_SortedPreferentialId, 'rowno', 'constituency_id')

    rowno = db.Column(db.Integer, primary_key=True)
    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'))
    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'))
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'))
    category_id = db.Column(db.Integer, db.ForeignKey('candidate_categories.id'))
    electoral_list_id = db.Column(db.Integer, db.ForeignKey('electoral_lists.id'))
    district_category_quota = db.Column(db.Integer)
    allocated_seats = db.Column(db.Integer)
    preferential_percentage = db.Column(db.Numeric)
    winning = db.Column(db.Boolean)


class FinalResult(View, db.Model):
    __tablename__ = 'results_preferential'

    FIELDS = [
        ROFieldColumn('constituency_id', 'Constituency', getname_filter(Constituency, 'name'), 'string', orderable=True, searchable=True, choices=Constituency),
        ROFieldColumn('electoral_list_id', 'List', getname_filter(ElectoralList, 'name'), 'string', orderable=True, searchable=True, choices=ElectoralList),
        ROFieldColumn('district_id', 'District', getname_filter(District, 'name'), 'string', orderable=True, searchable=True, choices=District),
        ROFieldColumn('category_id', 'Category', getname_filter(CandidateCategory, 'name'), 'string', orderable=True, searchable=True, choices=CandidateCategory),
        ROFieldColumn('candidate_id', 'Candidate', getname_filter(Candidate, 'name'), 'string', orderable=True, searchable=True, choices=Candidate),
        ROFieldColumn('preferential_percentage', 'Value (%)', noop_filter, 'number', orderable=True, searchable=False, choices=None),
    ]

    id = db.synonym('candidate_id')

    constituency_id = db.Column(db.Integer, db.ForeignKey('constituencies.id'))
    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'))
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'), primary_key=True)
    category_id = db.Column(db.Integer, db.ForeignKey('candidate_categories.id'))
    electoral_list_id = db.Column(db.Integer, db.ForeignKey('electoral_lists.id'))
    preferential_percentage = db.Column(db.Numeric)


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
        # TODO joins and type checks for the queries where possible
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


def escape_schema_name(schema_name):
    engine = db.engine
    preparer = engine.dialect.identifier_preparer
    return preparer.quote(schema_name, True)


def initialize_schema(schema_name, template_name='ar_dummy', checkfirst=True):
    assert template_name in TEMPLATE_NAMES
    if_exists = " IF NOT EXISTS " if checkfirst else ""
    sql_queries = render_template('simulation-templates/{}.sql.j2'.format(template_name))  # TODO we are not using it as a jinja2 template

    # conn = db.engine.raw_connection()
    # cur = conn.cursor()
    cur = db.session.connection().connection.cursor()
    cur.execute("CREATE SCHEMA {}{}".format(if_exists, escape_schema_name(schema_name)))
    cur.execute("SET search_path = {}, pg_catalog;".format(escape_schema_name(schema_name)))
    cur.execute(sql_queries)
    # cur.execute("COMMIT")


def humanize(template_name):
    return ' '.join(t.upper() if len(t) <= 2 else t.title() for t in template_name.split('_'))


@app.route('/')
def index():
    return render_template(
        'index.html',
        create_simulation_url=url_for('.create_simulation', _external=True),
        template_options=[(t, humanize(t)) for t in TEMPLATE_NAMES]
    )


@app.route('/simulation', methods=['POST'])
def create_simulation():
    rdm = random.SystemRandom()
    schema_name_seed = ''.join(rdm.choice(string.ascii_lowercase) for _ in range(10))
    simulation = Simulation(schema_name_seed=schema_name_seed)
    db.session.add(simulation)
    db.session.flush()
    initialize_schema(simulation.schema_name, template_name=request.form.get('template_name') or 'ar_dummy')
    db.session.commit()

    return jsonify({
        'data': {
            'name': create_hashid(simulation.id)
        },
        'success': True,
    })


@dt.route('/')
def simulation_iframe():
    tables = {k: v() for k, v in TABLES.items()}
    return render_template('simulation.html', tables=tables)


@dt.url_value_preprocessor
def with_simulation_name(endpoint, values):
    simulation_hashid = values.pop('simulation')
    simulation_id = decode_hashid(simulation_hashid)
    assert simulation_id is not None and simulation_id > 0
    g.simulation = simulation = Simulation.query.get(simulation_id)
    assert simulation is not None


@dt.before_request
def setup_schema_search_path():
    # print("Set schema search path to", g.simulation.schema_name)
    db.session.execute("SET search_path = {};".format(escape_schema_name(g.simulation.schema_name)))


@dt.url_defaults
def default_simulation_name(endpoint, values):
    if endpoint.startswith(dt.name + '.'):
        values.setdefault('simulation', create_hashid(g.simulation.id))


potato(dt, Constituency)
potato(dt, District)
potato(dt, CandidateCategory)
potato(dt, DistrictQuota)

potato(dt, ElectoralList)
potato(dt, Candidate)

potato(dt, VotesPerList)
potato(dt, PreferentialVote)

potato(dt, ConstituencyListSize)
potato(dt, ConstituencyTotalVotes)
potato(dt, ConstituencyInitialThreshold)
potato(dt, ConstituencyCountedVotes)
potato(dt, ListAllocations)
potato(dt, AdjustedListAllocations)

potato(dt, TotalPreferentialVotes)
potato(dt, SortedPreferentialList)
potato(dt, IllustratedFinalResult)
potato(dt, FinalResult)


app.register_blueprint(dt)
