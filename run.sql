
select * from electoral_lists;

select * from candidates;

select * from votes_per_list;

select * from constituency_list_size;

select * from constituency_total_votes;

select * from results_constituency_threshold;

select * from results_constituency_total_votes;

-- TODO article 94.4
select * from results_list_allocations;
select * from results_adjusted_list_allocations;

-- insert into preferential_votes select co.id, ca.id, 10 + round(random() * 560) from candidates ca join districts d on d.id = ca.district_id join consituencies co on co.id = d.constituency_id;

-- select d.id as district_id, sum(pv.value) as total_votes from preferential_votes pv join candidates ca on ca.id = pv.candidate_id join districts d on d.id = ca.district_id group by d.id;

select * from results_total_preferential_votes;

-- TODO order by percentages desc, candidate_age desc, coin_toss;

select * from results_preferential;

