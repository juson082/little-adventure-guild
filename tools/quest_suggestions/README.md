# Quest suggestion batches

The app does not yet collect quest suggestions. This Google Apps Script prepares a Google Form and emails each complete batch of 50 responses to `juson082@gmail.com`. Form responses stay in the Google account and can be reviewed in the form. No respondent email is requested. Ask submitters not to include personal information; Google still processes normal connection data.

1. Create a Google Apps Script project in the Google account that should own the form. Paste `Code.js` into the editor.
2. Run `setup` and grant the requested Forms, triggers and email permissions. The script creates a form, a form-submission trigger, and an hourly retry trigger. Running setup again reuses them.
3. In the execution log copy the respondent URL. Open the edit URL and verify the form is published and accepts responses without sign-in, and that email collection and one-response limits are disabled.
4. Provide the respondent URL so it can be connected to the app. Update the app and published privacy policy and Play data-safety declarations before releasing the feature.

Responses are sent in arrival order, 50 per email; fewer remain in the form until a batch is complete. The hourly trigger retries after an error or quota issue. Do not delete individual responses: the checkpoint is a count, and changing response history can cause skipped or duplicated items. Check script execution logs if mail stops. A crash between sending and saving the checkpoint can cause a duplicate batch; sending and checkpointing are not transactional. Apps Script and Google Forms have service quotas and availability limits. Do not publish the form until you are ready to accept submissions.
