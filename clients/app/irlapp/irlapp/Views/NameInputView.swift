// NameInputView.swift
// irlapp
//
// Created by Elijah Arbee on 10/30/24.
//

import SwiftUI

struct NameInputView: View {
    @Binding var userName: String
    @Binding var step: Int

    // Centralized manager for data, audio, and server handling
    @StateObject private var appManager = AppManager()

    @State private var receivedName: String = ""
    @State private var prosody: String = ""
    @State private var feeling: String = ""
    @State private var isCorrectName: Bool = true
    @State private var confirmedName: String = ""
    @State private var isRecording: Bool = false
    @State private var currentPrompt: String = "Say: \"Hello, I'm [your name]!\""
    @State private var showConfirmation: Bool = false

    private let greetings = [
        "Say: \"Hello, I'm [your name]!\"",
        "Di: \"Hola, soy [tu nombre]!\"",
        "Dire: \"Bonjour, je suis [votre nom]!\"",
        "Sag: \"Hallo, ich bin [dein Name]!\"",
        "说: \"你好，我是[你的名字]!\"",
        "Diga: \"Olá, eu sou [seu nome]!\"",
        "Say: \"こんにちは、私は[あなたの名前]です!\"",
        "Gul: \"Merhaba, ben [senin ismin]!\""
    ]

    private let demoWaveform: [CGFloat] = [0.2, 0.5, 0.3, 0.7, 0.2, 0.6, 0.4, 0.8, 0.3, 0.6, 0.4]
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            Spacer()

            if !showConfirmation {
                VStack(spacing: 20) {
                    Text(currentPrompt)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 30)
                        .onReceive(timer) { _ in
                            currentPrompt = greetings.randomElement() ?? currentPrompt
                        }

                    HStack(spacing: 6) {
                        ForEach(demoWaveform.indices, id: \.self) { index in
                            Capsule()
                                .fill(isRecording ? Color.blue.opacity(0.8) : Color.primary.opacity(0.4))
                                .frame(width: 4, height: demoWaveform[index] * 60)
                        }
                    }
                    .padding(.vertical, 30)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(16)
                    .shadow(radius: 5, y: 2)

                    Button(action: {
                        isRecording.toggle()
                        if isRecording {
                            appManager.startRecording()
                        } else {
                            appManager.stopRecordingAndSendAudio { result in
                                switch result {
                                case .success(let response):
                                    self.receivedName = response.name
                                    self.prosody = response.prosody
                                    self.feeling = response.feeling
                                    self.showConfirmation = true
                                case .failure(let error):
                                    // Handle error (e.g., show an alert)
                                    print("Error: \(error.localizedDescription)")
                                }
                            }
                        }
                    }) {
                        Text(isRecording ? "Listening..." : "Touch to Speak")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15).fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.white.opacity(0.2)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.2), radius: 10, x: 5, y: 5)
                            .shadow(color: Color.white.opacity(0.3), radius: 10, x: -5, y: -5)
                            .cornerRadius(15)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 10)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Text("Is this your name?")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(receivedName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 30)

                    Toggle(isOn: $isCorrectName) {
                        Text(isCorrectName ? "Yes, that's correct" : "No, I'll correct it")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)

                    if !isCorrectName {
                        TextField("Enter your name", text: $confirmedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                            .onAppear {
                                confirmedName = receivedName
                            }
                    }

                    Button(action: {
                        userName = isCorrectName ? receivedName : confirmedName
                        step += 1
                    }) {
                        Text("Submit")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 5, y: 2)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding()
        .alert(isPresented: $appManager.showingError) {
            Alert(
                title: Text("Error"),
                message: Text(appManager.errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
