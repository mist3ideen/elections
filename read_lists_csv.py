import csv
import glob
from pprint import pprint
from collections import namedtuple, defaultdict, Counter

ListItem = namedtuple('ListItem', 'filename, list_name, district, category, candidate_name')

def parsecandidate(row, filename):
    candidate_name, category, district, list_name, *ignore = row
    return ListItem(filename, list_name.strip(), district.strip(), category.strip(), candidate_name.strip())

def iterlists(pattern):
    for filename in glob.glob(pattern):
        with open(filename, 'r', encoding='utf-8') as f:
            csvreader = csv.reader(f)
            listbuildup = []
            for row in csvreader:
                if not any(row):
                    assert listbuildup, filename
                    yield listbuildup
                    listbuildup = []
                else:
                    listbuildup.append(parsecandidate(row, filename))
            if listbuildup:
                assert listbuildup, filename
                yield listbuildup

def grouplists(listlist):
    listdict = defaultdict(list)
    categories = Counter()
    for clist in listlist:
        list_names = set(cl.list_name for cl in clist)
        districts = tuple(sorted(set(cl.district for cl in clist)))
        assert len(list_names) == 1, repr((list_names, clist))
        listdict[districts].append(clist)
        for cl in clist:
            categories[cl.category] += 1
            # ~ categories[(cl.category, *districts)] += 1

    return listdict, categories

if __name__ == '__main__':
    # ~ pprint(list(iterlists('./*.csv')))
    # ~ pprint(grouplists(iterlists('./*.csv')))
    glist, categories = grouplists(iterlists('./*.csv'))
    for districts, clists in glist.items():
        print('/'.join(districts), ':', len(clists))
    print('Total:', sum(len(clists) for clists in glist.values()))

    pprint(categories)
