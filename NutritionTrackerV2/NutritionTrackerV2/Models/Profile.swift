//
//  Profile.swift
//  NutritionTrackerV2
//
//  Enhanced user profile model with health and nutrition preferences
//

import Foundation

// Note: Shared types like MealType, SyncStatus are defined in Models.swift

// MARK: - Profile Model

struct Profile: Codable, Identifiable, Hashable, Timestamped {
    let id: UUID
    let userId: UUID // Links to Auth user
    let username: String
    let customKey: String?

    // Personal Information
    let firstName: String?
    let lastName: String?
    let email: String?
    let dateOfBirth: Date?

    // Physical Characteristics
    let height: Double? // in centimeters
    let weight: Double? // in kilograms
    let sex: Sex?
    let activityLevel: ActivityLevel?

    // Health & Nutrition Goals
    let primaryGoal: NutritionGoal?
    let dailyCalorieGoal: Double?
    let dailyProteinGoal: Double? // in grams
    let dailyCarbGoal: Double? // in grams
    let dailyFatGoal: Double? // in grams
    let dailyFiberGoal: Double? // in grams
    let dailySodiumLimit: Double? // in mg

    // Dietary Preferences & Restrictions
    let dietaryRestrictions: [DietaryRestriction]
    let allergies: [Allergy]
    let preferences: ProfilePreferences

    // App Settings
    let preferredUnits: UnitSystem
    let timezone: String?
    let language: String?

    // Privacy & Sharing
    let isPublic: Bool
    let shareProgress: Bool
    let allowDataExport: Bool

    // Metadata
    let createdAt: Date
    let updatedAt: Date
    let lastActiveAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case customKey = "custom_key"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case dateOfBirth = "date_of_birth"
        case height
        case weight
        case sex
        case activityLevel = "activity_level"
        case primaryGoal = "primary_goal"
        case dailyCalorieGoal = "daily_calorie_goal"
        case dailyProteinGoal = "daily_protein_goal"
        case dailyCarbGoal = "daily_carb_goal"
        case dailyFatGoal = "daily_fat_goal"
        case dailyFiberGoal = "daily_fiber_goal"
        case dailySodiumLimit = "daily_sodium_limit"
        case dietaryRestrictions = "dietary_restrictions"
        case allergies
        case preferences
        case preferredUnits = "preferred_units"
        case timezone
        case language
        case isPublic = "is_public"
        case shareProgress = "share_progress"
        case allowDataExport = "allow_data_export"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastActiveAt = "last_active_at"
    }
}

// MARK: - Enums

enum Sex: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"
    case extremelyActive = "extremely_active"

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary (little/no exercise)"
        case .lightlyActive: return "Lightly Active (light exercise 1-3 days/week)"
        case .moderatelyActive: return "Moderately Active (moderate exercise 3-5 days/week)"
        case .veryActive: return "Very Active (hard exercise 6-7 days/week)"
        case .extremelyActive: return "Extremely Active (very hard exercise, physical job)"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }
}

enum NutritionGoal: String, Codable, CaseIterable {
    case maintainWeight = "maintain_weight"
    case loseWeight = "lose_weight"
    case gainWeight = "gain_weight"
    case buildMuscle = "build_muscle"
    case improveHealth = "improve_health"
    case manageCondition = "manage_condition"
    case sportPerformance = "sport_performance"

    var displayName: String {
        switch self {
        case .maintainWeight: return "Maintain Weight"
        case .loseWeight: return "Lose Weight"
        case .gainWeight: return "Gain Weight"
        case .buildMuscle: return "Build Muscle"
        case .improveHealth: return "Improve Overall Health"
        case .manageCondition: return "Manage Health Condition"
        case .sportPerformance: return "Optimize Sport Performance"
        }
    }
}

enum DietaryRestriction: String, Codable, CaseIterable {
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case pescatarian = "pescatarian"
    case keto = "keto"
    case paleo = "paleo"
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case lowCarb = "low_carb"
    case lowFat = "low_fat"
    case lowSodium = "low_sodium"
    case diabetic = "diabetic"
    case kosher = "kosher"
    case halal = "halal"

    var displayName: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .keto: return "Ketogenic"
        case .paleo: return "Paleo"
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        case .lowCarb: return "Low Carb"
        case .lowFat: return "Low Fat"
        case .lowSodium: return "Low Sodium"
        case .diabetic: return "Diabetic"
        case .kosher: return "Kosher"
        case .halal: return "Halal"
        }
    }
}

enum Allergy: String, Codable, CaseIterable {
    case peanuts = "peanuts"
    case treeNuts = "tree_nuts"
    case shellfish = "shellfish"
    case fish = "fish"
    case eggs = "eggs"
    case dairy = "dairy"
    case soy = "soy"
    case wheat = "wheat"
    case sesame = "sesame"
    case sulfites = "sulfites"

    var displayName: String {
        switch self {
        case .peanuts: return "Peanuts"
        case .treeNuts: return "Tree Nuts"
        case .shellfish: return "Shellfish"
        case .fish: return "Fish"
        case .eggs: return "Eggs"
        case .dairy: return "Dairy"
        case .soy: return "Soy"
        case .wheat: return "Wheat"
        case .sesame: return "Sesame"
        case .sulfites: return "Sulfites"
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"

    var displayName: String {
        switch self {
        case .metric: return "Metric (kg, cm)"
        case .imperial: return "Imperial (lbs, ft/in)"
        }
    }
}

// MARK: - Profile Preferences

struct ProfilePreferences: Codable, Hashable {
    let showCalories: Bool
    let showMacros: Bool
    let showMicros: Bool
    let showDailyGoals: Bool
    let enableNotifications: Bool
    let reminderTimes: [ReminderTime]
    let defaultMealType: MealType?
    let trackWater: Bool
    let trackExercise: Bool

    static let defaultPreferences = ProfilePreferences(
        showCalories: true,
        showMacros: true,
        showMicros: false,
        showDailyGoals: true,
        enableNotifications: true,
        reminderTimes: [],
        defaultMealType: nil,
        trackWater: true,
        trackExercise: false
    )
}

struct ReminderTime: Codable, Hashable {
    let mealType: MealType
    let time: String // HH:mm format
    let enabled: Bool
}

// MARK: - Profile Extensions

extension Profile {

    // MARK: - Computed Properties

    /// Full display name
    var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let lastName = lastName {
            return lastName
        }
        return username
    }

    /// Age in years
    var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    /// BMI calculation
    var bmi: Double? {
        guard let height = height, let weight = weight, height > 0 else { return nil }
        let heightInMeters = height / 100
        return weight / (heightInMeters * heightInMeters)
    }

    /// BMI category
    var bmiCategory: String? {
        guard let bmi = bmi else { return nil }
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal weight"
        case 25..<30: return "Overweight"
        case 30...: return "Obese"
        default: return nil
        }
    }

    /// Basal Metabolic Rate (BMR) using Mifflin-St Jeor Equation
    var bmr: Double? {
        guard let weight = weight,
              let height = height,
              let age = age,
              let sex = sex else { return nil }

        switch sex {
        case .male:
            return (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        case .female:
            return (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        case .other, .preferNotToSay:
            // Use average of male and female calculations
            let male = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
            let female = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
            return (male + female) / 2
        }
    }

    /// Total Daily Energy Expenditure (TDEE)
    var tdee: Double? {
        guard let bmr = bmr, let activityLevel = activityLevel else { return nil }
        return bmr * activityLevel.multiplier
    }

    /// Recommended daily calorie intake based on goal
    var recommendedDailyCalories: Double? {
        guard let tdee = tdee else { return nil }

        switch primaryGoal {
        case .loseWeight:
            return tdee - 500 // 1 lb per week loss
        case .gainWeight, .buildMuscle:
            return tdee + 300 // Conservative surplus
        case .maintainWeight, .improveHealth, .manageCondition, .sportPerformance, .none:
            return tdee
        }
    }

    // MARK: - Validation

    /// Whether the profile has complete basic information
    var hasCompleteBasicInfo: Bool {
        return !username.isEmpty && height != nil && weight != nil && age != nil
    }

    /// Whether the profile has nutrition goals set
    var hasNutritionGoals: Bool {
        return dailyCalorieGoal != nil || primaryGoal != nil
    }

    // MARK: - Factory Methods

    /// Create a minimal profile for a new user
    /// - Parameters:
    ///   - userId: The auth user ID
    ///   - username: The username
    ///   - email: Optional email
    /// - Returns: A new Profile instance with default values
    static func createMinimal(
        userId: UUID,
        username: String,
        email: String? = nil
    ) -> Profile {
        let now = Date()
        return Profile(
            id: UUID(),
            userId: userId,
            username: username,
            customKey: nil,
            firstName: nil,
            lastName: nil,
            email: email,
            dateOfBirth: nil,
            height: nil,
            weight: nil,
            sex: nil,
            activityLevel: nil,
            primaryGoal: nil,
            dailyCalorieGoal: nil,
            dailyProteinGoal: nil,
            dailyCarbGoal: nil,
            dailyFatGoal: nil,
            dailyFiberGoal: nil,
            dailySodiumLimit: nil,
            dietaryRestrictions: [],
            allergies: [],
            preferences: ProfilePreferences.defaultPreferences,
            preferredUnits: .metric,
            timezone: TimeZone.current.identifier,
            language: Locale.current.languageCode,
            isPublic: false,
            shareProgress: false,
            allowDataExport: true,
            createdAt: now,
            updatedAt: now,
            lastActiveAt: now
        )
    }

    // MARK: - Mutations

    /// Update profile with new information
    /// - Parameters:
    ///   - firstName: New first name
    ///   - lastName: New last name
    ///   - height: New height in cm
    ///   - weight: New weight in kg
    ///   - sex: New sex
    ///   - activityLevel: New activity level
    ///   - primaryGoal: New primary goal
    /// - Returns: Updated Profile instance
    func updated(
        firstName: String? = nil,
        lastName: String? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        sex: Sex? = nil,
        activityLevel: ActivityLevel? = nil,
        primaryGoal: NutritionGoal? = nil
    ) -> Profile {
        return Profile(
            id: self.id,
            userId: self.userId,
            username: self.username,
            customKey: self.customKey,
            firstName: firstName ?? self.firstName,
            lastName: lastName ?? self.lastName,
            email: self.email,
            dateOfBirth: self.dateOfBirth,
            height: height ?? self.height,
            weight: weight ?? self.weight,
            sex: sex ?? self.sex,
            activityLevel: activityLevel ?? self.activityLevel,
            primaryGoal: primaryGoal ?? self.primaryGoal,
            dailyCalorieGoal: self.dailyCalorieGoal,
            dailyProteinGoal: self.dailyProteinGoal,
            dailyCarbGoal: self.dailyCarbGoal,
            dailyFatGoal: self.dailyFatGoal,
            dailyFiberGoal: self.dailyFiberGoal,
            dailySodiumLimit: self.dailySodiumLimit,
            dietaryRestrictions: self.dietaryRestrictions,
            allergies: self.allergies,
            preferences: self.preferences,
            preferredUnits: self.preferredUnits,
            timezone: self.timezone,
            language: self.language,
            isPublic: self.isPublic,
            shareProgress: self.shareProgress,
            allowDataExport: self.allowDataExport,
            createdAt: self.createdAt,
            updatedAt: Date(),
            lastActiveAt: Date()
        )
    }

    /// Update nutrition goals
    /// - Parameters:
    ///   - calorieGoal: Daily calorie goal
    ///   - proteinGoal: Daily protein goal in grams
    ///   - carbGoal: Daily carb goal in grams
    ///   - fatGoal: Daily fat goal in grams
    /// - Returns: Updated Profile instance
    func updatedNutritionGoals(
        calorieGoal: Double? = nil,
        proteinGoal: Double? = nil,
        carbGoal: Double? = nil,
        fatGoal: Double? = nil
    ) -> Profile {
        return Profile(
            id: self.id,
            userId: self.userId,
            username: self.username,
            customKey: self.customKey,
            firstName: self.firstName,
            lastName: self.lastName,
            email: self.email,
            dateOfBirth: self.dateOfBirth,
            height: self.height,
            weight: self.weight,
            sex: self.sex,
            activityLevel: self.activityLevel,
            primaryGoal: self.primaryGoal,
            dailyCalorieGoal: calorieGoal ?? self.dailyCalorieGoal,
            dailyProteinGoal: proteinGoal ?? self.dailyProteinGoal,
            dailyCarbGoal: carbGoal ?? self.dailyCarbGoal,
            dailyFatGoal: fatGoal ?? self.dailyFatGoal,
            dailyFiberGoal: self.dailyFiberGoal,
            dailySodiumLimit: self.dailySodiumLimit,
            dietaryRestrictions: self.dietaryRestrictions,
            allergies: self.allergies,
            preferences: self.preferences,
            preferredUnits: self.preferredUnits,
            timezone: self.timezone,
            language: self.language,
            isPublic: self.isPublic,
            shareProgress: self.shareProgress,
            allowDataExport: self.allowDataExport,
            createdAt: self.createdAt,
            updatedAt: Date(),
            lastActiveAt: self.lastActiveAt
        )
    }
}

// MARK: - Sample Data

extension Profile {

    /// Sample profile data for testing and previews
    static let sampleProfile = Profile(
        id: UUID(),
        userId: UUID(),
        username: "johndoe",
        customKey: nil,
        firstName: "John",
        lastName: "Doe",
        email: "john.doe@example.com",
        dateOfBirth: Calendar.current.date(from: DateComponents(year: 1990, month: 6, day: 15)),
        height: 175, // cm
        weight: 70, // kg
        sex: .male,
        activityLevel: .moderatelyActive,
        primaryGoal: .maintainWeight,
        dailyCalorieGoal: 2200,
        dailyProteinGoal: 110,
        dailyCarbGoal: 275,
        dailyFatGoal: 73,
        dailyFiberGoal: 25,
        dailySodiumLimit: 2300,
        dietaryRestrictions: [],
        allergies: [],
        preferences: ProfilePreferences.defaultPreferences,
        preferredUnits: .metric,
        timezone: "America/New_York",
        language: "en",
        isPublic: false,
        shareProgress: true,
        allowDataExport: true,
        createdAt: Date(),
        updatedAt: Date(),
        lastActiveAt: Date()
    )
}