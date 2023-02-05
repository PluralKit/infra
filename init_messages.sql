create table messages (
    mid bigint not null primary key,
    channel bigint not null,
    member integer,
    sender bigint not null,
    original_mid bigint,
    guild bigint
);
