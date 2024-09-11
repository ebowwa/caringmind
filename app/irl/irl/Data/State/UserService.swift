//
//  UserService.swift
//  irl
//
//  Created by Elijah Arbee on 9/9/24.
//
import Foundation

class UserService {
    func loadUser(completion: @escaping (Result<User, Error>) -> Void) {
        // Simulate network call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let user = User(id: UUID(), name: "John Doe", email: "john@example.com")
            completion(.success(user))
        }
    }
}
