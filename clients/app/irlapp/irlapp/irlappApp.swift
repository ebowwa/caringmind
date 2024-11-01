/**
import SwiftUI

@main
struct CaringMindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, World!")
    }
}
*/
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
import Combine
import GoogleSignIn
import GoogleSignInSwift
import ReSwift

@main
struct irlappApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate 

    @StateObject private var appLifecycleManager = AppLifecycleManager()
    @StateObject private var router = AppRouterViewModel()
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appLifecycleManager)
                .environmentObject(router)
                .environmentObject(onboardingViewModel)
                .onAppear {
                    appLifecycleManager.setupLifecycleObservers()
                    // Start recording by dispatching action to `store`
                    store.dispatch(StartRecordingAction(deviceID: UUID())) // Replace UUID() with actual device ID if available
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

// AppLifecycleManager using `store` for lifecycle events
// ViewModels/AppLifecycleManager.swift

import Combine
import SwiftUI

class AppLifecycleManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var lastState: AppLifecycleState?

    enum AppLifecycleState {
        case didEnterBackground, willEnterForeground, didBecomeActive
    }

    func setupLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleState(.didEnterBackground)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleState(.willEnterForeground)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleState(.didBecomeActive)
            }
            .store(in: &cancellables)
    }

    private func handleState(_ state: AppLifecycleState) {
        guard lastState != state else { return }
        lastState = state

        switch state {
        case .didEnterBackground:
            print("App entered background.")
            store.dispatch(DeactivateAudioSessionAction())
            store.dispatch(StopRecordingAction(deviceID: UUID())) // Replace with actual device ID as needed

        case .willEnterForeground:
            print("App will enter foreground.")
            store.dispatch(ConfigureAudioSessionAction(category: .playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers]))
            store.dispatch(StartRecordingAction(deviceID: UUID())) // Resume recording

        case .didBecomeActive:
            print("App became active.")
            store.dispatch(AudioSessionResumedAction()) // Resumes audio session if needed
        }
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
    @EnvironmentObject var appLifecycleManager: AppLifecycleManager
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

