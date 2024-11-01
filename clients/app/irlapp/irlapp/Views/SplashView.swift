/** //
//  SplashView.swift
//  CaringMind
//
//  Created by Elijah Arbee on 10/30/24.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift // Ensure this import is present

struct SplashView: View {
    @EnvironmentObject var router: AppRouterViewModel

    var body: some View {
        ZStack {
            SplashBackgroundGradientView(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.5)]) // Softer gradient
            
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon and Welcome Message
                Image(systemName: "leaf.fill") // Placeholder icon, replace with custom CaringMind icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
                    .padding(.bottom, 10)
                
                Text("Welcome to CaringMind")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Optional Tagline or Inspirational Message
                Text("Align with Purpose")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 5)
                
                Spacer()

                // Google Sign-In Button
                GoogleSignInButton {
                    signInWithGoogle()
                }
                .frame(width: 230, height: 55)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                .padding(.vertical, 10)
                
                // "Get Started" Button for new users
                Button(action: {
                    router.navigate(to: .onboarding)
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.bottom, 30) // Adjusted bottom padding for spacing consistency
        }
    }
    
    private func signInWithGoogle() {
        // Obtain the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Root view controller not found.")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                print("Sign-In failed: \(error.localizedDescription)")
                return
            }
            
            if let signInResult = signInResult {
                // Handle sign-in success
                print("User signed in successfully: \(signInResult.user.profile?.name ?? "Unknown")")
                // Navigate to home or update state based on sign-in
                router.navigate(to: .home)
            }
        }
    }
}

struct SplashBackgroundGradientView: View {
    var colors: [Color] = [Color.blue, Color.purple]

    var body: some View {
        LinearGradient(gradient: Gradient(colors: colors),
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
}
*/
