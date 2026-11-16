// Run setup() once in Google Apps Script. It creates a form and its triggers.
const RECIPIENT = 'juson082@gmail.com';
const BATCH_SIZE = 50;

function setup() {
  const props = PropertiesService.getScriptProperties();
  let formId = props.getProperty('formId');
  let form;
  if (formId) {
    form = FormApp.openById(formId);
  } else {
    form = FormApp.create('Hvildir — Quest Suggestions');
    form.setDescription('Share a small experience that could become a quest. Please do not include personal or sensitive information. Suggestions are reviewed by the developer.');
    form.setCollectEmail(false);
    form.addTextItem().setTitle('Quest title').setRequired(true);
    form.addParagraphTextItem().setTitle('Quest description').setRequired(true);
    props.setProperty('formId', form.getId());
    props.setProperty('sentCount', '0');
  }
  const triggers = ScriptApp.getProjectTriggers();
  if (!triggers.some(t => t.getHandlerFunction() === 'sendQuestBatches' && t.getEventType() === ScriptApp.EventType.ON_FORM_SUBMIT)) {
    ScriptApp.newTrigger('sendQuestBatches').forForm(form).onFormSubmit().create();
  }
  if (!triggers.some(t => t.getHandlerFunction() === 'sendQuestBatches' && t.getEventType() === ScriptApp.EventType.CLOCK)) {
    ScriptApp.newTrigger('sendQuestBatches').timeBased().everyHours(1).create();
  }
  console.log('Respondent URL: ' + form.getPublishedUrl());
  console.log('Edit URL: ' + form.getEditUrl());
}

function sendQuestBatches() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) throw new Error('Unable to acquire batch lock');
  try {
    const props = PropertiesService.getScriptProperties();
    const formId = props.getProperty('formId');
    if (!formId) throw new Error('Run setup first');
    const responses = FormApp.openById(formId).getResponses();
    let sent = Number(props.getProperty('sentCount') || 0);
    if (!Number.isInteger(sent) || sent < 0 || sent > responses.length) {
      throw new Error('Response count changed; check the form before resuming.');
    }
    while (responses.length - sent >= BATCH_SIZE) {
      const batch = responses.slice(sent, sent + BATCH_SIZE);
      const body = batch.map((response, index) => {
        const fields = response.getItemResponses().map(item =>
          item.getItem().getTitle() + ': ' + item.getResponse());
        return (sent + index + 1) + '. ' + response.getTimestamp().toISOString() + '\n' + fields.join('\n');
      }).join('\n\n');
      MailApp.sendEmail(RECIPIENT, 'Hvildir quest suggestions ' + (sent + 1) + '–' + (sent + BATCH_SIZE), body);
      // A failure after sendEmail but before this checkpoint can duplicate a batch.
      sent += BATCH_SIZE;
      props.setProperty('sentCount', String(sent));
    }
  } finally {
    lock.releaseLock();
  }
}
