import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/routes.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/mountain/mountain_list_screen.dart';
import 'screens/mountain/mountain_detail_screen.dart';
import 'screens/simaksi/simaksi_form_screen.dart';
import 'screens/simaksi/simaksi_payment_screen.dart';
import 'screens/simaksi/simaksi_ticket_screen.dart';
import 'screens/basecamp/basecamp_dashboard_screen.dart';
import 'screens/basecamp/ticket_verify_screen.dart';
import 'screens/basecamp/hiker_monitor_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/weather/weather_screen.dart';
import 'screens/compass/compass_screen.dart';
import 'screens/safety/fall_detection_screen.dart';
import 'screens/safety/sos_beacon_screen.dart';
import 'screens/ai/survival_assistant_screen.dart';
import 'screens/game/mountain_climber_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/personal_data_screen.dart';
import 'screens/profile/medical_profile_screen.dart';
import 'screens/feedback/course_feedback_screen.dart';

class MainApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'TimurLang',
      theme: AppTheme.auraTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.mountainList: (context) => const MountainListScreen(),
        AppRoutes.mountainDetail: (context) => const MountainDetailScreen(),
        AppRoutes.simaksiForm: (context) => const SimaksiFormScreen(),
        AppRoutes.simaksiPayment: (context) => const SimaksiPaymentScreen(),
        AppRoutes.simaksiTicket: (context) => const SimaksiTicketScreen(),
        AppRoutes.basecampDashboard: (context) => const BasecampDashboardScreen(),
        AppRoutes.ticketVerify: (context) => const TicketVerifyScreen(),
        AppRoutes.hikerMonitor: (context) => const HikerMonitorScreen(),
        AppRoutes.map: (context) => const MapScreen(),
        AppRoutes.weather: (context) => const WeatherScreen(),
        AppRoutes.compass: (context) => const CompassScreen(),
        AppRoutes.fallDetection: (context) => const FallDetectionScreen(),
        AppRoutes.sos: (context) => const SosBeaconScreen(),
        AppRoutes.survivalAssistant: (context) => const SurvivalAssistantScreen(),
        AppRoutes.mountainClimber: (context) => const MountainClimberScreen(),
        AppRoutes.profile: (context) => const ProfileScreen(),
        AppRoutes.personalData: (context) => const PersonalDataScreen(),
        AppRoutes.medicalProfile: (context) => const MedicalProfileScreen(),
        AppRoutes.courseFeedback: (context) => const CourseFeedbackScreen(),
      },
    );
  }
}
