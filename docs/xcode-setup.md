# Xcode Project Setup Guide

## Adding Supabase Swift SDK

### Step 1: Open Xcode Project
```bash
open /Users/diegoserranoa/Developer/ios/nutrition-tracker/NutritionTrackerV2/NutritionTrackerV2.xcodeproj
```

### Step 2: Add Swift Package Manager Dependency

1. **Select Project**: In Xcode Navigator, click on the blue "NutritionTrackerV2" project file
2. **Select Target**: Choose the "NutritionTrackerV2" app target
3. **Package Dependencies**: Click on the "Package Dependencies" tab
4. **Add Package**: Click the "+" button to add a new package

### Step 3: Add Supabase Swift SDK

**Package URL**: `https://github.com/supabase/supabase-swift`

**Version Requirements**:
- Dependency Rule: "Up to Next Major Version"
- Version: `2.0.0` (or latest available)

### Step 4: Select Package Products

When prompted, select these package products for the NutritionTrackerV2 target:
- ✅ **Supabase** (Core client library)
- ✅ **Auth** (Authentication features)
- ✅ **PostgREST** (Database operations)
- ✅ **Storage** (File storage)
- ✅ **Realtime** (Real-time subscriptions)

### Step 5: Verify Installation

After adding the package, verify it appears in:
- **Project Navigator** → NutritionTrackerV2 → **Package Dependencies** → supabase-swift
- **Target Settings** → NutritionTrackerV2 → **Frameworks, Libraries, and Embedded Content**

### Step 6: Test Import

Create a test import in any Swift file:
```swift
import Supabase
import Auth
import PostgREST
import Storage
import Realtime
```

## Expected Project Structure

After successful integration:
```
NutritionTrackerV2.xcodeproj/
├── project.pbxproj (updated with package references)
└── project.xcworkspace/
    └── xcshareddata/
        └── swiftpm/
            └── Package.resolved (created automatically)

Package Dependencies (in Xcode):
└── supabase-swift
    ├── Auth
    ├── PostgREST
    ├── Realtime
    ├── Storage
    └── Supabase
```

## Troubleshooting

### Package Resolution Issues
If package resolution fails:
1. **Reset Package Caches**: File → Swift Packages → Reset Package Caches
2. **Update to Latest Package Versions**: File → Swift Packages → Update to Latest Package Versions
3. **Check Network**: Ensure internet connectivity for GitHub access

### Build Errors
If build fails after adding packages:
1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Restart Xcode**: Close and reopen Xcode
3. **Check iOS Deployment Target**: Ensure it matches Supabase requirements (iOS 13.0+)

### Import Errors
If imports fail:
1. **Verify Package Products**: Check target's package dependencies
2. **Check Target Membership**: Ensure files are added to correct target
3. **Build Project**: Sometimes imports work after first successful build

## Next Steps

After successful installation:
1. ✅ Verify all imports work
2. ✅ Create SupabaseManager singleton
3. ✅ Configure client with project credentials
4. ✅ Test basic connectivity

## Manual Verification Commands

Run these in Terminal to verify the setup:
```bash
# Check if Package.resolved was created
ls -la "/Users/diegoserranoa/Developer/ios/nutrition-tracker/NutritionTrackerV2/NutritionTrackerV2.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/"

# Check project file for package references
grep -i "supabase" "/Users/diegoserranoa/Developer/ios/nutrition-tracker/NutritionTrackerV2/NutritionTrackerV2.xcodeproj/project.pbxproj"
```