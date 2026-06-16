"use strict";

// OCL Study Cloud Functions — 진입점.
// 모든 알림 함수는 notifications/ 모듈에서 정의하고 여기서 재노출한다.
// (Firebase 는 export 된 v2 함수들을 자동 배포한다.)

const assignments = require("./notifications/assignments");
const flashcards = require("./notifications/flashcards");
const aiQuestions = require("./notifications/aiQuestions");
const dueSoon = require("./notifications/dueSoon");
const aiProxy = require("./https/aiProxy");

module.exports = {
  ...assignments,
  ...flashcards,
  ...aiQuestions,
  ...dueSoon,
  ...aiProxy,
};
