//
//  MessageDemoView.swift
//  SwiftAnthropicExample
//
//  Created by James Rochabrun on 2/24/24.
//

import Foundation
import PhotosUI
import SwiftAnthropic
import SwiftUI

@MainActor
struct MessageDemoView: View {
   
   let observable: MessageDemoObservable
   @State private var selectedSegment: ChatConfig = .messageStream
   @State private var prompt = ""
   
   @State private var selectedItems: [PhotosPickerItem] = []
   @State private var selectedImages: [Image] = []
   @State private var selectedImagesEncoded: [String] = []

   enum ChatConfig {
      case message
      case messageStream
   }
   
   var body: some View {
      ScrollView {
         VStack {
            picker
            Text(observable.errorMessage)
               .foregroundColor(.red)
            messageView
         }
         .padding()
      }
      .overlay(
         Group {
            if observable.isLoading {
               ProgressView()
            } else {
               EmptyView()
            }
         }
      ).safeAreaInset(edge: .bottom) {
         VStack(spacing: 0) {
            selectedImagesView
            textArea
         }
      }
   }
   
   var textArea: some View {
      HStack(spacing: 4) {
         TextField("Enter prompt", text: $prompt, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .padding()
         photoPicker
         Button {
            Task {
               
               let images: [MessageParameter.Message.Content.ContentObject] = selectedImagesEncoded.map {
                  .image(.init(type: .base64, mediaType: .jpeg, data: $0))
               }
               let text: [MessageParameter.Message.Content.ContentObject] = [.text(prompt)]
               
               let finalInput = images + text
               
               let messages = [MessageParameter.Message(role: .user, content: .list(finalInput))]
               
               prompt = ""
               let parameters = MessageParameter(
                  model: .claude35Sonnet,
                  messages: messages,
                  maxTokens: 1024,
                  system: .objects([
                     .init(type: .text, text: "You are a pirate"),
                  ]))
               switch selectedSegment {
               case .message:
                  try await observable.createMessage(parameters: parameters)
               case .messageStream:
                  try await observable.streamMessage(parameters: parameters)
               }
            }
         } label: {
            Image(systemName: "paperplane")
         }
         .buttonStyle(.bordered)
      }
      .padding()
   }
   
   var picker: some View {
      Picker("Options", selection: $selectedSegment) {
         Text("Message").tag(ChatConfig.message)
         Text("Message Stream").tag(ChatConfig.messageStream)
      }
      .pickerStyle(SegmentedPickerStyle())
      .padding()
   }
   
   var messageView: some View {
      VStack(spacing: 24) {
         HStack {
            Button("Cancel") {
               observable.cancelStream()
            }
            Button("Clear Message") {
               observable.clearMessage()
            }
         }
         Text(observable.message)
      }
      .buttonStyle(.bordered)
   }
   
   var photoPicker: some View {
      PhotosPicker(selection: $selectedItems, matching: .images) {
         Image(systemName: "photo")
      }
      .onChange(of: selectedItems) {
         Task {
            selectedImages.removeAll()
            for item in selectedItems {
               
               if let data = try? await item.loadTransferable(type: Data.self) {
                  if let uiImage = UIImage(data: data), let resizedImageData = uiImage.jpegData(compressionQuality: 0.7) {
                      // Make sure the resized image is below the size limit
                     // This is needed as Claude allows a max of 5Mb size per image.
                      if resizedImageData.count < 5_242_880 { // 5 MB in bytes
                          let base64String = resizedImageData.base64EncodedString()
                          selectedImagesEncoded.append(base64String)
                          let image = Image(uiImage: UIImage(data: resizedImageData)!)
                          selectedImages.append(image)
                      } else {
                          // Handle the error - maybe resize to an even smaller size or show an error message to the user
                      }
                  }
               }
            }
         }
      }
   }
   
   var selectedImagesView: some View {
      HStack(spacing: 0) {
         ForEach(0..<selectedImages.count, id: \.self) { i in
            selectedImages[i]
               .resizable()
               .frame(width: 60, height: 60)
               .clipShape(RoundedRectangle(cornerRadius: 12))
               .padding(4)
         }
      }
   }
}
