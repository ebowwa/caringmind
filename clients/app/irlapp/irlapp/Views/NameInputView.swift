/**
//  NameInputView.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/30/24.
//


import SwiftUI

// Step 4: Confirm user's name based on server response
struct NameInputView: View {
    @Binding var userName: String
    @Binding var step: Int

    // Simulated server response data
    @State private var receivedName: String = "Alan Rodrigues" // Replace with actual server response
    @State private var prosody: String = "" // To store 'prosody' from server
    @State private var feeling: String = "" // To store 'feeling' from server

    @State private var isCorrectName: Bool = true
    @State private var confirmedName: String = "" // of the server response only the name is shown

    @State private var isRecording: Bool = false
    @State private var currentPrompt: String = "Say: \"Hello, I'm [your name]!\""

    // Multilingual greetings array
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

    // Simulated audio wave data for demo purposes
    private let demoWaveform: [CGFloat] = [0.2, 0.5, 0.3, 0.7, 0.2, 0.6, 0.4, 0.8, 0.3, 0.6, 0.4]

    // Timer to change the greeting every few seconds
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // State to manage UI mode: Recording or Confirmation
    @State private var showConfirmation: Bool = false

    var body: some View {
        VStack {
            Spacer()

            if !showConfirmation {
                // **Recording Interface**
                VStack(spacing: 20) {
                    // Dynamic Prompt in Multiple Languages
                    Text(currentPrompt)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 30)
                        .onReceive(timer) { _ in
                            withAnimation {
                                currentPrompt = greetings.randomElement() ?? currentPrompt
                            }
                        }

                    // Waveform visualization placeholder
                    HStack(spacing: 6) {
                        ForEach(demoWaveform, id: \.self) { amplitude in
                            Capsule()
                                .fill(isRecording ? Color.blue.opacity(0.8) : Color.primary.opacity(0.4))
                                .frame(width: 4, height: amplitude * 60)
                        }
                    }
                    .padding(.vertical, 30)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(16)
                    .shadow(radius: 5, y: 2)

                    // "Touch to Speak" button styled as an ice cube
                    Button(action: {
                        isRecording.toggle()
                        if isRecording {
                            // Start audio recording logic here
                            // TODO: Integrate actual audio recording functionality
                        } else {
                            // Stop recording and process audio data
                            // TODO: Send audio data to server and handle response
                            // For demo purposes, we'll simulate receiving a server response
                            simulateServerResponse()
                        }
                    }) {
                        Text(isRecording ? "Listening..." : "Touch to Speak")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.white.opacity(0.2)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                                    .shadow(color: Color.blue.opacity(0.2), radius: 10, x: 5, y: 5)
                                    .shadow(color: Color.white.opacity(0.3), radius: 10, x: -5, y: -5)
                            )
                            .cornerRadius(15)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 10)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                // **Confirmation Interface**
                VStack(spacing: 20) {
                    // Display the name returned by the server
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

                    // Toggle to indicate if the name is correct
                    Toggle(isOn: $isCorrectName) {
                        Text(isCorrectName ? "Yes, that's correct" : "No, I'll correct it")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)

                    // TextField for editing the name if the toggle is set to "incorrect"
                    if !isCorrectName {
                        TextField("Enter your name", text: $confirmedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                            .onAppear {
                                confirmedName = receivedName // Populate with server name initially
                            }
                    }

                    // Confirm button
                    Button(action: {
                        // This action will later send the name confirmation or correction to the backend
                        // For demo purposes, we'll simulate the confirmation
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
        .onAppear {
            // Simulate receiving data from server after recording
            // TODO: Replace with actual server response handling
        }
    }

    // **Simulate Server Response**
    private func simulateServerResponse() {
        // Simulate a delay for server processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Example: Assign prosody and feeling from server
            self.receivedName = "Alan Rodrigues" // Replace with actual server response
            self.prosody = "The user's pronunciation of 'Alan' is somewhat hesitant..."
            self.feeling = "The delivery has a slight air of reluctance..."

            // Switch to confirmation interface
            self.showConfirmation = true
        }
    }
}

/**
struct AudioLevelView: View {
    @ObservedObject private var viewModel: AudioLevelViewModel

    init(audioLevelPublisher: AnyPublisher<Float, Never>) {
        self.viewModel = AudioLevelViewModel(audioLevelPublisher: audioLevelPublisher)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 6) {
                ForEach(viewModel.audioLevels, id: \.self) { level in
                    Capsule()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 4, height: CGFloat(level) * geometry.size.height)
                }
            }
        }
    }
}

class AudioLevelViewModel: ObservableObject {
    @Published var audioLevels: [Float] = Array(repeating: 0.1, count: 20)
    private var cancellables = Set<AnyCancellable>()

    init(audioLevelPublisher: AnyPublisher<Float, Never>) {
        audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self else { return }
                // Normalize level between 0 and 1
                let normalizedLevel = min(max((level + 100) / 100, 0), 1)
                self.audioLevels.append(normalizedLevel)
                if self.audioLevels.count > 20 {
                    self.audioLevels.removeFirst()
                }
            }
            .store(in: &cancellables)
    }
}

*/
*/
