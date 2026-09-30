import Anthropic from "@anthropic-ai/sdk";
import type { CategoryOption, Extraction } from "./handler.ts";
import { SYSTEM, toExtraction, userPrompt, type RawExtraction } from "./prompt.ts";

/** Pemanggil Claude (dipertahankan sebagai pembanding/cadangan; lihat README). */
export function makeExtractor(apiKey: string, model = "claude-haiku-4-5") {
  const client = new Anthropic({ apiKey });
  return async function extract(
    rawText: string,
    categories: CategoryOption[],
  ): Promise<Extraction> {
    const response = await client.messages.create({
      model,
      max_tokens: 300,
      system: `${SYSTEM}
Selalu jawab dengan memanggil tool record_receipt.`,
      tools: [
        {
          name: "record_receipt",
          description: "Catat hasil ekstraksi struk.",
          input_schema: {
            type: "object",
            properties: {
              merchant: { type: ["string", "null"] },
              category_id: {
                type: ["string", "null"],
                enum: [...categories.map((c) => c.id), null],
              },
              total: { type: ["integer", "null"] },
              date: { type: ["string", "null"] },
            },
            required: ["merchant", "category_id", "total", "date"],
          },
        },
      ],
      tool_choice: { type: "tool", name: "record_receipt" },
      messages: [{ role: "user", content: userPrompt(rawText, categories) }],
    });
    const block = response.content.find((b) => b.type === "tool_use");
    if (!block || block.type !== "tool_use") throw new Error("no tool_use in response");
    return toExtraction(block.input as RawExtraction);
  };
}
