//
//  Config.swift.example
//  NutritionTrackerV2
//
//  Supabase configuration for the iOS app
//  Copy this file to Config.swift and fill in your actual values
//

import Foundation

struct SupabaseConfig {
    static let url = "https://hcskwwdqmgilvasqeqxh.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjc2t3d2RxbWdpbHZhc3FlcXhoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg1ODUyMzUsImV4cCI6MjA3NDE2MTIzNX0.ENCHvALhZE5iG-mBuJjLrzULe6yOPMY31qBjJDloWVM"
}

// MARK: - Usage
// Initialize Supabase client with these values:
// let supabase = SupabaseClient(
//     supabaseURL: URL(string: SupabaseConfig.url)!,
//     supabaseKey: SupabaseConfig.anonKey
// )