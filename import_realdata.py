from uielections.application import *
from read_lists_csv import *

import itertools
import os
import sys


def import_data(csv_directory, session):
    pattern = os.path.join(csv_directory, '*.csv')
    glist, _ = grouplists(iterlists(pattern))

    category_map = {}
    district_map = {}
    constituency_map = {}
    electoral_list_map = {}
    candidate_map = {}
    district_constituency_map = {
        dis: cons
        for cons in glist.keys()
        for dis in cons
    }

    def candidatelist(grouped):
        return (can for clists in grouped.values() for clist in clists for can in clist)

    for cons in glist.keys():
        assert cons not in constituency_map
        constituency_map[cons] = Constituency(name='/'.join(cons))

    session.add_all(constituency_map.values())
    session.flush()

    for dis in set(can.district for can in candidatelist(glist)):
        cons = district_constituency_map[dis]
        consobj = constituency_map[cons]
        assert dis not in district_map
        district_map[dis] = District(name=dis, constituency_id=consobj.id)

    session.add_all(district_map.values())
    session.flush()

    for cat in set(can.category for can in candidatelist(glist)):
        assert cat not in category_map
        category_map[cat] = CandidateCategory(name=cat)

    session.add_all(category_map.values())
    session.flush()

    for cons, clists in glist.items():
        consobj = constituency_map[cons]
        for clist in clists:
            lname = clist[0].list_name
            assert (cons, lname) not in electoral_list_map
            electoral_list_map[cons, lname] = ElectoralList(name=lname, constituency_id=consobj.id)

    session.add_all(electoral_list_map.values())
    session.flush()

    for cons, clists in glist.items():
        consobj = constituency_map[cons]
        for clist in clists:
            lname = clist[0].list_name
            for can in clist:
                cname = can.candidate_name
                disobj = district_map[can.district]
                catobj = category_map[can.category]
                elobj = electoral_list_map[cons, lname]
                assert (cons, lname, cname) not in candidate_map
                candidate_map[cons, lname, cname] = Candidate(name=cname, district_id=disobj.id, category_id=catobj.id, electoral_list_id=elobj.id)

    session.add_all(candidate_map.values())
    session.flush()

    # Assuming each constituency has at least one "full" list
    session.execute('insert into district_quotas (district_id, category_id, value) select district_id, category_id, max(quota) from (select district_id, category_id, electoral_list_id, count(id) as quota from candidates group by district_id, category_id, electoral_list_id) as t group by district_id, category_id;')
    session.flush()


if __name__ == '__main__':
    try:
        csv_directory = sys.argv[1]
    except IndexError:
        csv_directory = './candidates/tabula-Lists2018_ocr_gray/'
    import_data(csv_directory, db.session)
    db.session.commit()
