const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const values = { formId: 'form', sentCount: '0' };
const emails = [];
let count = 49;
let fail = false;
let unlocked = false;
const context = {
  PropertiesService: { getScriptProperties: () => ({
    getProperty: key => values[key],
    setProperty: (key, value) => { values[key] = value; },
  }) },
  LockService: { getScriptLock: () => ({
    tryLock: () => true,
    releaseLock: () => { unlocked = true; },
  }) },
  FormApp: { openById: () => ({ getResponses: () => Array.from({ length: count }, (_, i) => ({
    getTimestamp: () => new Date(0),
    getItemResponses: () => [{ getItem: () => ({ getTitle: () => 'Quest' }), getResponse: () => String(i + 1) }],
  })) }) },
  MailApp: { sendEmail: (...args) => { if (fail) throw Error('quota'); emails.push(args); } },
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(__dirname + '/Code.js', 'utf8'), context);
context.sendQuestBatches();
assert.equal(emails.length, 0);
count = 101;
context.sendQuestBatches();
assert.equal(emails.length, 2);
assert.equal(values.sentCount, '100');
assert.match(emails[0][2], /Quest: 50/);
assert.match(emails[1][2], /Quest: 100/);
count = 150;
fail = true;
assert.throws(() => context.sendQuestBatches(), /quota/);
assert.equal(values.sentCount, '100');
assert.equal(unlocked, true);
fail = false;
context.sendQuestBatches();
assert.equal(values.sentCount, '150');
assert.equal(emails.length, 3);
console.log('Batch, retry and checkpoint checks passed.');
