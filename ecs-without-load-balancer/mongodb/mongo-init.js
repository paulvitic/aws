db.auth('root', 'password');

test = db.getSiblingDB('test');

test.createUser({
    user: 'testUser',
    pwd: 'password',
    roles: [ "readWrite" ]
});

test.eventLog.createIndex({ aggregateType: 1 });
test.eventLog.createIndex({ aggregateId: 1 });
test.eventLog.createIndex({ timeStamp: 1 });

