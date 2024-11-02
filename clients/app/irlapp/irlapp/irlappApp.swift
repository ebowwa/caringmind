
//  irlappApp.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/26/24.
//
// NOTE: this product is meant to listen 24/7 it uses the openaudio which allows for processing of audio from devices and storing, post requests, websocket, audio playing controls, local audio measurement, etc
// - this app should always be recording, it may be recording for local storage, for batch uploads to server, or for a live-streaming websocket
// - this functionality should not be managed by views, but can be modified, i.e., switch to websocket, send data to server, playbacks, viewing transcriptions, data, etc
// NOTE: this script was updated to include a google sign in which as of now does nothing, it works, the user can sign in with their google account but otherwise this feature has no other extension
// irlappApp.swift

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

@main
struct irlApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var router = AppRouterViewModel()
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(onboardingViewModel)
                .onAppear {
                    // Removed framework state and audio-related initializations
                }
        }
    }
}

// AppDelegate for Google Sign-In URL handling
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// AppRouterViewModel for navigation management
// ViewModels/AppRouterViewModel.swift

class AppRouterViewModel: ObservableObject {
    @Published var currentDestination: RouterDestination = .splash // Initialize to splash

    func navigate(to destination: RouterDestination) {
        withAnimation {
            currentDestination = destination
        }
    }

    func navigateToOnboarding() {
        currentDestination = .onboarding
    }

    func navigateToHome() {
        currentDestination = .home
    }
}

enum RouterDestination: Identifiable {
    case splash
    case onboarding
    case home

    var id: UUID {
        UUID()
    }
}

// ContentView with Onboarding and Google Sign-In button
struct ContentView: View {
    @EnvironmentObject var router: AppRouterViewModel
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            switch router.currentDestination {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingIntroView(step: $onboardingViewModel.currentStep,
                                    userName: $onboardingViewModel.userName,
                                    age: $onboardingViewModel.age)
                    .transition(.slide)
            case .home:
                EmptyView()
                    .transition(.slide)
            }
        }
        .animation(.easeInOut, value: router.currentDestination)
    }
}
