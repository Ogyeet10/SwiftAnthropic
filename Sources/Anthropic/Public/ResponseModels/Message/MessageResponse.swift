//
//  MessageResponse.swift
//
//
//  Created by James Rochabrun on 1/28/24.
//

import Foundation

/// [Message Response](https://docs.anthropic.com/claude/reference/messages_post)
public struct MessageResponse: Decodable {
   /// Unique object identifier.
   ///
   /// The format and length of IDs may change over time.
   public let id: String
   
   /// e.g: "message"
   public let type: String
   
   /// The model that handled the request.
   public let model: String
   
   /// Conversational role of the generated message.
   ///
   /// This will always be "assistant".
   public let role: String
   
   /// Array of Content objects representing blocks of content generated by the model.
   ///
   /// Each content block has a `type` that determines its structure.
   ///
   /// - Example text:
   ///   ```
   ///   [{"type": "text", "text": "Hi, I'm Claude."}]
   ///   ```
   ///
   /// The response content seamlessly follows from the last turn if the request input ends with an assistant turn. This allows for a continuous output based on the last interaction.
   ///
   /// - Example Input:
   ///   ```
   ///   [
   ///     {"role": "user", "content": "What's the Greek name for Sun? (A) Sol (B) Helios (C) Sun"},
   ///     {"role": "assistant", "content": "The best answer is ("}
   ///   ]
   ///   ```
   ///
   /// - Example Output:
   ///   ```
   ///   [{"type": "text", "text": "B)"}]
   ///   ```
   ///
   ///   ***Beta***
   ///
   /// - Example tool use:
   ///   ```
   ///   [{"type": "tool_use", "id": "toolu_01A09q90qw90lq917835lq9", "name": "get_weather", "input": { "location": "San Francisco, CA", "unit": "celsius"}}]
   ///   ```
   /// This structure facilitates the integration and manipulation of model-generated content within your application.
   public let content: [Content]
   
   /// indicates why the process was halted.
   ///
   /// This property can hold one of the following values to describe the stop reason:
   /// - `"end_turn"`: The model reached a natural stopping point.
   /// - `"max_tokens"`: The requested `max_tokens` limit or the model's maximum token limit was exceeded.
   /// - `"stop_sequence"`: A custom stop sequence provided by you was generated.
   ///
   /// It's important to note that the values for `stopReason` here differ from those in `/v1/complete`, specifically in how `end_turn` and `stop_sequence` are distinguished.
   ///
   /// - In non-streaming mode, `stopReason` is always non-null, indicating the reason for stopping.
   /// - In streaming mode, `stopReason` is null in the `message_start` event and non-null in all other cases, providing context for the stoppage.
   ///
   /// This design allows for a detailed understanding of the process flow and its termination points.
   public let stopReason: String?
   
   /// Which custom stop sequence was generated.
   ///
   /// This value will be non-null if one of your custom stop sequences was generated.
   public let stopSequence: String?
   
   /// Container for the number of tokens used.
   public let usage: Usage
   
   public enum Content: Codable {
      public typealias Input = [String: DynamicContent]
      
      public struct ToolUse: Codable {
         public let id: String
         public let name: String
         public let input: [String: MessageResponse.Content.DynamicContent]
      }
      
      case text(String)
      case toolUse(ToolUse)
      
      private enum CodingKeys: String, CodingKey {
         case type, text, id, name, input
      }
      
      public enum DynamicContent: Codable {
         case string(String)
         case integer(Int)
         case double(Double)
         case dictionary(Input)
         case array([DynamicContent])
         case bool(Bool)
         case null
         
         public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int.self) {
               self = .integer(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
               self = .double(doubleValue)
            } else if let stringValue = try? container.decode(String.self) {
               self = .string(stringValue)
            } else if let boolValue = try? container.decode(Bool.self) {
               self = .bool(boolValue)
            } else if container.decodeNil() {
               self = .null
            } else if let arrayValue = try? container.decode([DynamicContent].self) {
               self = .array(arrayValue)
            } else if let dictionaryValue = try? container.decode([String: DynamicContent].self) {
               self = .dictionary(dictionaryValue)
            } else {
               throw DecodingError.dataCorruptedError(in: container, debugDescription: "Content cannot be decoded")
            }
         }
         
         public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let val):
               try container.encode(val)
            case .integer(let val):
               try container.encode(val)
            case .double(let val):
               try container.encode(val)
            case .dictionary(let val):
               try container.encode(val)
            case .array(let val):
               try container.encode(val)
            case .bool(let val):
               try container.encode(val)
            case .null:
               try container.encodeNil()
            }
         }
      }
      
      public init(from decoder: Decoder) throws {
         let container = try decoder.container(keyedBy: CodingKeys.self)
         let type = try container.decode(String.self, forKey: .type)
         switch type {
         case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
         case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decode(Input.self, forKey: .input)
            self = .toolUse(ToolUse(id: id, name: name, input: input))
         default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid type value found in JSON!")
         }
      }
      
      public func encode(to encoder: any Encoder) throws {
         var container = encoder.container(keyedBy: CodingKeys.self)
         switch self {
         case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
         case .toolUse(let toolUse):
            try container.encode("tool_use", forKey: .type)
            try container.encode(toolUse.id, forKey: .id)
            try container.encode(toolUse.name, forKey: .name)
            try container.encode(toolUse.input, forKey: .input)
         }
      }
   }
   
   public struct Usage: Codable {
      /// The number of input tokens which were used.
      public let inputTokens: Int?
      
      /// The number of output tokens which were used.
      public let outputTokens: Int
      
      /// [Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching#how-can-i-track-the-effectiveness-of-my-caching-strategy)
      /// You can monitor cache performance using the cache_creation_input_tokens and cache_read_input_tokens fields in the API response.
      public let cacheCreationInputTokens: Int?
      
      /// [Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching#how-can-i-track-the-effectiveness-of-my-caching-strategy)
      /// You can monitor cache performance using the cache_creation_input_tokens and cache_read_input_tokens fields in the API response.
      public let cacheReadInputTokens: Int?
   }
}
