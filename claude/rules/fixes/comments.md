## Code comments

<!-- TODO: Needs re-testing on sonnet 4.6 and opus 4.6 -->

### Changes to code

When commenting on code, always write in reference to the latest state of the code, unless the change should be explicitly called out.

- **BAD:** comment states the obvious
  ```js
  // fetch ther user
  const userInfo = await externalUserApi(userId);
  ```
- **GOOD:** comment explains ambiguous argument needed for api with reason
  ```js
  // api requires explicit null to avoid nested table joins, we aggregate extra data elsewhere
  const userInfo = await externalUserApi(userId, null);
  ```
- **BAD:** comment explains a change relative to old code, which no longer makes sense in isolation (this is the role of `git diff` and changelogs)
  ```diff
  - // api requires explicit null to avoid nested table joins, we aggregate extra data elsewhere
  - const userInfo = await externalUserApi(userId, null)
  + // api no longer requires null to avoid joins
  + const userInfo = await externalUserApiV2(userId)
  ```
- **BAD:** comment removed on improved api
  ```diff
  - // api requires explicit null to avoid nested table joins, we aggregate extra data elsewhere
  - const userInfo = await externalUserApi(userId, null)
  + const userInfo = await externalUserApiV2(userId)
  ```
