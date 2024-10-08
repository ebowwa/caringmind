//
//  ArenaView.swift
//  irl
//
//  Created by Elijah Arbee on 10/7/24.
//
//
//  SocialViewB.swift
//  irl
//
//  Created by Elijah Arbee on 10/2/24.
//
import SwiftUI

// Updated model with articulated naming
struct DemoPostData: Identifiable {
    var id = UUID()
    var username: String
    var timeAgo: String
    var postImage: String
    var postTitle: String
    var postDescription: String
    var hashtags: [String]
    var likes: Int
    var hearts: Int
}

// Sample demo data
let sampleDemoPosts: [DemoPostData] = [
    DemoPostData(username: "Gianna A", timeAgo: "12m ago", postImage: "omi", postTitle: "Exploring SwiftUI", postDescription: "A deep dive into building responsive UIs with SwiftUI.", hashtags: ["#SwiftUI", "#iOS", "#Development"], likes: 10, hearts: 2),
    DemoPostData(username: "Alex B", timeAgo: "30m ago", postImage: "waveform", postTitle: "Live", postDescription: "", hashtags: [], likes: 0, hearts: 0),
    DemoPostData(username: "Elena C", timeAgo: "1h ago", postImage: "cityscape", postTitle: "Urban Exploration", postDescription: "Discovering hidden spots in the city.", hashtags: ["#Photography", "#Urban", "#Adventure"], likes: 34, hearts: 8),
    DemoPostData(username: "Michael D", timeAgo: "2h ago", postImage: "mountains", postTitle: "Into the Wild", postDescription: "Escaping the city for a peaceful retreat in the mountains.", hashtags: ["#Nature", "#Mountains", "#Travel"], likes: 57, hearts: 12)
]

// Placeholder for production data
let productionPosts: [DemoPostData] = [
    // Add actual production data here
]

struct SocialViewB: View {
    @State private var selectedTag: String = "All"
    @State private var showDropDown: Bool = false
    @State private var hidePlugins: Bool = false
    @State private var scrollOffset: CGFloat = 0.0
    @State private var username: String = "Guest"
    
    // Determine the data based on the mode
    var posts: [DemoPostData] {
        return Constants.devMode ? sampleDemoPosts : productionPosts
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text(Constants.productionMode ? "Hey \(username)" : "kellyjane") // Updated to pull the user's name
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    // Brain icon with NavigationLink to ChatView
                    NavigationLink(destination: ChatView()) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .onAppear {
                    // Load the username if in production mode
                    if Constants.productionMode {
                        username = UserDefaults.standard.string(forKey: "username") ?? "User"
                    }
                }
                
                // Plugins Horizontal ScrollView
                if !hidePlugins {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(1..<5) { index in
                                VStack {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.gray)
                                    Text("Plugin \(index)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.leading, index == 1 ? 16 : 0)
                            }
                        }
                    }
                    .padding(.vertical)
                    .transition(.slide)
                }

                // Tags/Filters TODO: EMBEDDINGS topic clusters these will be for the devmode only prod will need further work
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        TagButtonView(tag: "All", selectedTag: $selectedTag)
                        TagButtonView(tag: "SwiftUI", selectedTag: $selectedTag)
                        TagButtonView(tag: "iOS", selectedTag: $selectedTag)
                        TagButtonView(tag: "Development", selectedTag: $selectedTag)
                    }
                    .padding(.horizontal)
                }
                .background(Color(UIColor.systemGray6))

                Divider()

                // Posts ScrollView
                ScrollView {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                scrollOffset = geometry.frame(in: .global).minY
                            }
                            .onChange(of: geometry.frame(in: .global).minY) { oldValue, newValue in
                                // Updated 'onChange' to conform to iOS 17.0 changes
                                if newValue < scrollOffset {
                                    withAnimation {
                                        hidePlugins = true
                                    }
                                } else {
                                    withAnimation {
                                        hidePlugins = false
                                    }
                                }
                                scrollOffset = newValue
                            }
                    }
                    .frame(height: 0) // Invisible frame just for capturing scroll

                    VStack(spacing: 12) {
                        ForEach(posts) { post in
                            CPostView(post: post)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
                // Removed the Bottom Bar section as requested
            }
        }
    }
}

// TagButtonView for managing tags in horizontal scroll; these tags will differ by whatever topic clusters are most relevant to the users life
struct TagButtonView: View {
    var tag: String
    @Binding var selectedTag: String

    var body: some View {
        Button(action: {
            selectedTag = tag
        }) {
            Text("#\(tag)")
                .fontWeight(selectedTag == tag ? .bold : .regular)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .foregroundColor(selectedTag == tag ? .white : .gray)
                .background(selectedTag == tag ? Color.blue : Color.clear)
                .cornerRadius(15)
        }
    }
}

struct CPostView: View {
    var post: DemoPostData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
                VStack(alignment: .leading) {
                    Text(post.username)
                        .fontWeight(.medium)
                    Text(post.timeAgo)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.blue)
                Text("Plugin")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if !post.postImage.isEmpty {
                Image(post.postImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipped()
                    .background(Color.cyan)
                    .cornerRadius(10)
            }
            
            Text(post.postTitle)
                .font(.headline)
            if !post.postDescription.isEmpty {
                Text(post.postDescription)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                ForEach(post.hashtags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            
            // Heart and Thumbs down with gradient animation
            HStack(spacing: 16) {
                GradientPulsatingButton(
                    imageName: "heart.fill",
                    gradientColors: [Color.pink, Color.purple],
                    buttonSize: 24,
                    shadowColor: Color.purple,
                    shadowRadius: 10,
                    shadowOffsetX: 0,
                    shadowOffsetY: 5
                )
                GradientPulsatingButton(
                    imageName: "hand.thumbsdown.fill",
                    gradientColors: [Color.red, Color.orange],
                    buttonSize: 24,
                    shadowColor: Color.orange,
                    shadowRadius: 10,
                    shadowOffsetX: 0,
                    shadowOffsetY: 5
                )
                Spacer()
                Image(systemName: "square.and.arrow.up.fill")
            }
            .font(.footnote)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 3)
    }
}
