//
//  Food.swift
//  GOPeat
//
//  Created by jonathan calvin sutrisna on 26/03/25.
//

import Foundation
import SwiftData

@Model
class Food: Identifiable {
    var id: UUID = UUID()
    var name: String
    var desc: String
    var tenant: Tenant?
    var categories: [FoodCategory] = []
    init(name: String, description: String, categories: [FoodCategory], tenant: Tenant?) {
        self.name = name
        self.desc = description
        self.categories = categories
        self.tenant = tenant
    }
}
enum FoodCategory: String, CaseIterable, Codable {
    case spicy = "Spicy"
    case soup = "Soup"
    case roasted = "Roasted"
    case savory = "Savory"
    case sweet = "Sweet"
    case meat = "Meat"
    case vegetables = "Vegetables"
    case rice = "Rice"
    case seafood = "Seafood"
    case fried = "Fried"
    case chicken = "Chicken"
    case eggs = "Eggs"
    case nuts = "Nuts"
    case porkAndLard = "Pork and Lard"
    case fish = "Fish"
    case soy = "Soy"
    case mushroom = "Mushroom"
    case steamed = "Steamed"
    case gluten = "Gluten"
    case sour = "Sour"
    case snacks = "Snacks"
    case unknown = "Unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = FoodCategory(rawValue: value) ?? .unknown
    }
}
