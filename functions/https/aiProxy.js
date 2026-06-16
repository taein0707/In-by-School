"use strict";

// Gemini 프록시 — API 키를 클라이언트에 노출하지 않기 위한 서버 중계(H-2).
// 클라이언트는 Firebase ID 토큰을 실어 이 엔드포인트를 호출하고, 키는
// Functions Secret(GEMINI_API_KEY)에 보관된다. 키가 든 바이너리는 배포되지 않는다.
//
// 계약(POST, JSON):
//   헤더 Authorization: Bearer <Firebase ID 토큰>   (필수 — 인증 사용자만)
//   바디 { prompt: string, temperature?: number, model?: string }
//   응답 { text: string, usage: {promptTokenCount, candidatesTokenCount, totalTokenCount} }
//
// 프롬프트 구성/파싱은 클라이언트(GeminiService)가 그대로 담당하고, 여기선
// '키 보관 + Gemini 호출'만 해 로직 중복을 피한다.

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { admin } = require("../lib/messaging");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const DEFAULT_MODEL = "gemini-3.5-flash";

async function verify(req) {
  const header = req.get("Authorization") || "";
  const m = header.match(/^Bearer (.+)$/);
  if (!m) return null;
  try {
    return await admin.auth().verifyIdToken(m[1]);
  } catch (_) {
    return null;
  }
}

const aiProxy = onRequest(
  { secrets: [GEMINI_API_KEY], cors: true, timeoutSeconds: 30, memory: "256MiB" },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "method_not_allowed" });

    const user = await verify(req);
    if (!user) return res.status(401).json({ error: "unauthenticated" });

    const key = GEMINI_API_KEY.value();
    if (!key) return res.status(503).json({ error: "no_key" });

    const prompt = (req.body && req.body.prompt) || "";
    if (typeof prompt !== "string" || prompt.trim().length < 4) {
      return res.status(400).json({ error: "bad_prompt" });
    }
    const temperature =
      typeof (req.body && req.body.temperature) === "number" ? req.body.temperature : 0.4;
    const model = (req.body && req.body.model) || DEFAULT_MODEL;

    try {
      const r = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-goog-api-key": key },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { temperature, responseMimeType: "application/json" },
          }),
        }
      );
      if (!r.ok) return res.status(502).json({ error: "upstream", status: r.status });
      const body = await r.json();
      const text =
        body.candidates &&
        body.candidates[0] &&
        body.candidates[0].content &&
        body.candidates[0].content.parts &&
        body.candidates[0].content.parts[0] &&
        body.candidates[0].content.parts[0].text;
      if (!text) return res.status(502).json({ error: "empty" });
      return res.json({ text, usage: body.usageMetadata || {} });
    } catch (_) {
      return res.status(500).json({ error: "proxy_failed" });
    }
  }
);

module.exports = { aiProxy };
