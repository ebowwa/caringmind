//  Onboarding.swift
//  irlapp
// - the user name will pivot from a text input to a user speech
//  Created by Elijah Arbee on 10/30/24.
//
import SwiftUI
import Combine
import GoogleSignIn
import GoogleSignInSwift
import ReSwift

struct OnboardingIntroView: View {
    @EnvironmentObject var router: AppRouterViewModel
    @Binding var step: Int
    @Binding var userName: String
    @Binding var age: String

    var body: some View {
        ZStack {
            BackgroundGradientView()
            
            VStack {
                Spacer()
                
                // Handle step logic using the step state variable
                switch step {
                case 0:
                    WelcomeView(step: $step)
                case 1:
                    MomentsThoughtsEmotionsView(step: $step)
                case 2:
                    ManageDataView(step: $step)
                case 3:
                    MasterDataView(step: $step)
                case 4:
                    NameInputView(userName: $userName, step: $step)
                case 5:
                    AgeInputView(age: $age, step: $step, userName: userName)
                case 6:
                    FinalStepView(userName: userName, age: age)
                        .onAppear {
                            // Optionally, you can navigate to home after a delay
                            // Here, navigation is handled within FinalStepView upon button tap
                        }
                default:
                    // If step exceeds, navigate to home
                    Text("Onboarding Complete")
                        .onAppear {
                            router.navigate(to: .home)
                        }
                }
                
                Spacer()
            }
        }
    }
}


// Gradient background as a reusable view
struct BackgroundGradientView: View {
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// Step 0: Welcome
struct WelcomeView: View {
    @Binding var step: Int

    var body: some View {
        Text("Welcome.")
            .font(.title2)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    step += 1
                }
            }
    }
}

// Step 1: Moments, thoughts, emotions
struct MomentsThoughtsEmotionsView: View {
    @Binding var step: Int

    var body: some View {
        Text("Everything in life is data—moments, thoughts, emotions.")
            .font(.title2)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    step += 1
                }
            }
    }
}

// Step 2: Managing data
struct ManageDataView: View {
    @Binding var step: Int

    var body: some View {
        Text("How you manage that data shapes your day and empowers your future.")
            .font(.title2)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    step += 1
                }
            }
    }
}

// Step 3: Mastering data
struct MasterDataView: View {
    @Binding var step: Int

    var body: some View {
        Text("We're here to help you master it. Let’s start with something simple.")
            .font(.title2)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    step += 1
                }
            }
    }
}


// Step 5: Asking for user's age
struct AgeInputView: View {
    @Binding var age: String
    @Binding var step: Int
    var userName: String

    var body: some View {
        VStack {
            Text("Great to meet you, \(userName)! How old are you?")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.bottom, 10)

            TextField("Enter your age", text: $age)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .shadow(radius: 5)

            Button(action: {
                if !age.isEmpty {
                    step += 1
                }
            }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(age.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .disabled(age.isEmpty)
        }
    }
}

// Step 6: Final step after collecting user name and age
// import SwiftUI
// import GoogleSignIn

struct FinalStepView: View {
    var userName: String
    var age: String
    @EnvironmentObject var router: AppRouterViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Thanks, \(userName).")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("You are \(age) years old. Let’s get started on your journey.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
            
            Spacer()
            
            // Google Sign-In Button
            GoogleSignInButton {
                signInWithGoogle()
            }
            .frame(width: 220, height: 50)
            .padding()
            
            // Optional: A button to finish onboarding and go to home
            Button(action: {
                router.navigate(to: .home)
            }) {
                Text("Finish")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(BackgroundGradientView())
        .edgesIgnoringSafeArea(.all)
    }
    
    private func signInWithGoogle() {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                print("Sign-In failed: \(error.localizedDescription)")
                return
            }
            
            if let signInResult = signInResult {
                // Handle sign-in success
                print("User signed in successfully: \(signInResult.user.profile?.name ?? "Unknown")")
                // Navigate to home or update state as needed
                router.navigate(to: .home)
            }
        }
    }
}


// OnboardingViewModel

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 0 {
        didSet {
            saveCurrentStep()
        }
    }

    @Published var userName: String = "" {
        // the user input should be an audio file
        // the user will say '{greeting}, im {username}
        // we will then send the audio to backend and the backend will respond with
        /**
         {
           "type": "object",
           "properties": {
             "name": {
               "type": "string",
               "description": "The user's full name.",
               "example": "Alan Rodrigues"
             },
             "prosody": {
               "type": "string",
               "description": "An analysis of the user's speech characteristics, including pronunciation and any noticeable inflections.",
               "example": "The user's pronunciation of 'Alan' is somewhat hesitant, with a noticeable pause before saying 'Rodrigues'. This suggests they may be somewhat self-conscious about their name, or perhaps they're more comfortable with the surname than the given name."
             },
             "feeling": {
               "type": "string",
               "description": "An interpretation of the user's emotional tone based on their speech pattern.",
               "example": "There's a slight air of reluctance in the delivery, suggesting the user might not be entirely comfortable sharing their name in this context."
             }
           },
           "required": [
             "name",
             "prosody",
             "feeling"
           ]
         }
         */
        // we will only display the user name however! and we will save the other results alongside the name
        // if the spelling is wrong the user should correct, if the name is totally wrong the user should be prompted to repeat the greeting and name one last final time
        // use openaudio for this
        didSet {
            userInputs["userName"] = userName
            saveUserInputs()
        }
    }

    @Published var age: String = "" {
        didSet {
            userInputs["age"] = age
            saveUserInputs()
        }
    }

    @Published var userInputs: [String: String] = [:] {
        didSet {
            saveUserInputs()
        }
    }

    let totalSteps: Int = 7

    var progressValue: Double {
        return Double(currentStep) / Double(totalSteps)
    }

    init() {
        loadState()
    }

    func saveCurrentStep() {
        UserDefaults.standard.set(currentStep, forKey: "currentStep")
    }

    func saveUserInputs() {
        UserDefaults.standard.set(userInputs, forKey: "userInputs")
    }

    func loadState() {
        currentStep = UserDefaults.standard.integer(forKey: "currentStep")
        userInputs = UserDefaults.standard.dictionary(forKey: "userInputs") as? [String: String] ?? [:]
        userName = userInputs["userName"] ?? ""
        age = userInputs["age"] ?? ""
    }

    func nextStep() {
        if currentStep < totalSteps {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
}

