create extension timescaledb;

create table messages (
    mid bigint not null primary key,
    channel bigint not null,
    member integer,
    sender bigint not null,
    original_mid bigint,
    guild bigint
);

select create_hypertable('messages', 'mid', chunk_time_interval => 362387865600000);