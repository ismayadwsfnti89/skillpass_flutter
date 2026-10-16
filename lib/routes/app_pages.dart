import 'package:flutter_mya/routes/app_routes.dart';
import 'package:flutter_mya/screens/splash/splash_screen.dart';
import 'package:flutter_mya/screens/auth/login_page.dart';
import 'package:flutter_mya/screens/auth/register_page.dart';
import 'package:flutter_mya/screens/dashboard/dashboard_page.dart';
import 'package:flutter_mya/screens/profile/profile_page.dart';
import 'package:flutter_mya/screens/profile/edit_profile_page.dart';
import 'package:flutter_mya/screens/survey/survey_list_page.dart';
import 'package:flutter_mya/screens/survey/survey_form_page.dart';
import 'package:flutter_mya/screens/survey/survey_detail_page.dart';
import 'package:go_router/go_router.dart';

class AppPages {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) {
          final profile = state.extra as Map<String, dynamic>?;
          return EditProfilePage(profile: profile);
        },
      ),
      GoRoute(
        path: AppRoutes.surveyList,
        builder: (context, state) => const SurveyListPage(),
      ),
      GoRoute(
        path: AppRoutes.surveyForm,
        builder: (context, state) {
          final survey = state.extra as Map<String, dynamic>?;
          return SurveyFormPage(survey: survey);
        },
      ),
      GoRoute(
        path: AppRoutes.surveyDetail,
        builder: (context, state) {
          final id = state.extra as int?;
          return SurveyDetailPage(surveyId: id ?? 0);
        },
      ),
    ],
  );
}