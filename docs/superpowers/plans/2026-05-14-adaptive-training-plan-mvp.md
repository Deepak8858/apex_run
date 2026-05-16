# Adaptive Training Plan MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Runna-style adaptive training plan MVP that turns ApexRun's daily coach into a multi-week, recovery-aware training calendar.

**Architecture:** Add a deterministic `AdaptivePlanService` that generates `PlannedWorkout` rows from a small goal profile, recent activity history, and optional recovery score. Wire it into the existing Riverpod `CoachController`, `WorkoutDataSource`, and `CoachScreen` so users can create a plan without new backend schema. Store generated sessions in the existing `planned_workouts` table.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase, existing `PlannedWorkout`, existing `WeeklyStats`, `flutter_test`.

---

## File Structure

- Create `lib/data/services/adaptive_plan_service.dart`: deterministic plan generation, options model, summary model, load/recovery guardrails.
- Modify `lib/presentation/providers/app_providers.dart`: provider, controller state, `generateAdaptivePlan`.
- Modify `lib/data/datasources/workout_datasource.dart`: batch insert helper for generated plans.
- Modify `lib/presentation/screens/coach_screen.dart`: add goal controls, plan generation button, plan summary, and upcoming schedule context.
- Create `test/unit/adaptive_plan_service_test.dart`: TDD coverage for plan generation, ramping, recovery deload, and missed-day realignment behavior.

## Task 1: Plan Engine

**Files:**
- Create: `test/unit/adaptive_plan_service_test.dart`
- Create: `lib/data/services/adaptive_plan_service.dart`

- [ ] **Step 1: Write failing tests**

Cover:

- A 10K plan generates 4 weeks of workouts, including long runs and quality sessions.
- Low recovery suppresses interval/tempo intensity in the first week.
- Weekly distance does not ramp above 12% from week to week.
- Plans honor preferred training weekdays.

- [ ] **Step 2: Run failing tests**

Run: `flutter test test/unit/adaptive_plan_service_test.dart`

Expected: fail because `AdaptivePlanService` does not exist.

- [ ] **Step 3: Implement service**

Create options and summary classes plus `generatePlan()` returning `AdaptivePlanResult`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/unit/adaptive_plan_service_test.dart`

Expected: all adaptive plan unit tests pass.

## Task 2: Persistence Hook

**Files:**
- Modify: `lib/data/datasources/workout_datasource.dart`

- [ ] **Step 1: Add a failing datasource API expectation by compile path**

Use the controller integration compile as the verification target, because Supabase client calls are integration-bound in this codebase.

- [ ] **Step 2: Add `createWorkouts(List<PlannedWorkout>)`**

Insert multiple rows into `planned_workouts` with `.insert(payload).select()`.

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`

Expected: no missing method errors.

## Task 3: Riverpod Controller

**Files:**
- Modify: `lib/presentation/providers/app_providers.dart`

- [ ] **Step 1: Add provider**

Add `adaptivePlanServiceProvider`.

- [ ] **Step 2: Extend `CoachState`**

Add `isGeneratingPlan`, `planSummary`, and keep existing daily workout fields untouched.

- [ ] **Step 3: Add `generateAdaptivePlan`**

Fetch current user, recent 28-day activities, optional recovery score, generate plan, save workouts, invalidate `todaysWorkoutProvider` and `upcomingWorkoutsProvider`, and update state with summary.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`

Expected: controller compiles without state or provider errors.

## Task 4: Coach UI

**Files:**
- Modify: `lib/presentation/screens/coach_screen.dart`

- [ ] **Step 1: Add plan action card**

Add a compact "Build adaptive plan" section below the coach header with a segmented goal dropdown, plan length dropdown, and primary action.

- [ ] **Step 2: Add plan summary**

Show generated plan summary after successful creation: goal, weeks, total workouts, first week distance, and adaptation note.

- [ ] **Step 3: Preserve current daily workout behavior**

Do not remove the daily workout generator, insight card, form analysis card, or upcoming workout list.

- [ ] **Step 4: Run widget tests**

Run: `flutter test test/widget/coach_screen_test.dart`

Expected: existing coach component tests still pass.

## Task 5: Verification

**Files:**
- All touched files.

- [ ] **Step 1: Run focused tests**

Run: `flutter test test/unit/adaptive_plan_service_test.dart test/widget/coach_screen_test.dart`

Expected: all tests pass.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`

Expected: no issues found.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`

Expected: all tests pass.

## Self-Review

The plan covers the approved first feature slice from the competitor analysis: adaptive plan generation, recovery-aware adjustment, persistence into existing planned workouts, and Coach screen access. It intentionally avoids schema changes, watch/device integrations, social comments, route safety, and ML retraining because those are later phases.
