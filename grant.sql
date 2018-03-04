GRANT CONNECT, CREATE, TEMPORARY ON DATABASE elections TO electionsweb ;
GRANT USAGE ON SCHEMA public, simulation TO electionsweb ;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public, simulation TO electionsweb ;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO electionsweb ;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA simulation TO electionsweb ;
