import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/core/utils/date_formatter.dart';
import 'package:kreatif_otopart/data/database/database_helper.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_otopart/presentation/screens/auth/login_screen.dart';
import 'package:kreatif_otopart/presentation/screens/main_screen.dart';
import 'package:kreatif_otopart/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:kreatif_otopart/data/repositories/auth_repository.dart';
import 'package:kreatif_otopart/data/repositories/customer_repository.dart';
import 'package:kreatif_otopart/data/repositories/order_repository.dart';
import 'package:kreatif_otopart/data/repositories/report_repository.dart';
import 'package:kreatif_otopart/data/repositories/service_repository.dart';
import 'package:kreatif_otopart/data/repositories/user_repository.dart';
import 'package:kreatif_otopart/data/repositories/supplier_repository.dart';
import 'package:kreatif_otopart/data/repositories/purchase_order_repository.dart';
import 'package:kreatif_otopart/data/repositories/product_repository.dart';
import 'package:kreatif_otopart/data/repositories/payment_repository.dart'; // Add import
import 'package:kreatif_otopart/data/repositories/settings_repository.dart';
import 'package:kreatif_otopart/logic/cubits/order/order_cubit.dart';
import 'package:kreatif_otopart/data/repositories/service_reminder_repository.dart';
import 'package:kreatif_otopart/logic/cubits/service_reminder/service_reminder_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/settings/settings_cubit.dart';
import 'package:kreatif_otopart/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for Windows
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize all at once
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    DateFormatter.initialize(),
    DatabaseHelper.instance.database,
    NotificationService().init(),
  ]);

  final prefs = results[0] as SharedPreferences;
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  runApp(MyApp(showOnboarding: showOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;

  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => ServiceRepository()),
        RepositoryProvider(create: (_) => OrderRepository()),
        RepositoryProvider(create: (_) => CustomerRepository()),
        RepositoryProvider(create: (_) => ReportRepository()),
        RepositoryProvider(create: (_) => UserRepository()),
        RepositoryProvider(create: (_) => SupplierRepository()),
        RepositoryProvider(create: (_) => PurchaseOrderRepository()),
        RepositoryProvider(create: (_) => ProductRepository()),         
        RepositoryProvider(create: (_) => PaymentRepository()), // Add PaymentRepository
        RepositoryProvider(create: (_) => SettingsRepository()),
        RepositoryProvider(create: (_) => ServiceReminderRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthCubit(
              authRepository: context.read<AuthRepository>(),
            )..checkAuthStatus(),
          ),
          BlocProvider(
            create: (context) => OrderCubit(
              orderRepository: context.read<OrderRepository>(),
              productRepository: context.read<ProductRepository>(),
              customerRepository: context.read<CustomerRepository>(), // Inject CustomerRepository
              paymentRepository: context.read<PaymentRepository>(), // Inject PaymentRepository
            )..loadOrders(),
          ),
          BlocProvider(
            create: (context) => SettingsCubit(
              repository: context.read<SettingsRepository>(),
            )..loadSettings(),
          ),
          BlocProvider(
            create: (context) => ServiceReminderCubit(
              repository: context.read<ServiceReminderRepository>(),
            )..loadReminders(),
          ),
        ],
        child: MaterialApp(
          title: 'POS Offline',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: AuthWrapper(showOnboarding: showOnboarding),
        ),
      ),
    );
  }
}

/// Wrapper widget that handles auth state changes
class AuthWrapper extends StatefulWidget {
  final bool showOnboarding;

  const AuthWrapper({super.key, required this.showOnboarding});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
  }

  void _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        // Show loading indicator while checking auth status
        if (state is AuthInitial || state is AuthLoading) {
          return Scaffold(
            backgroundColor: AppThemeColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.xlRadius,
                      boxShadow: AppShadows.medium,
                    ),
                    child: Image.asset(
                      'assets/icons/logobengkel.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const CircularProgressIndicator(
                    color: AppThemeColors.primary,
                  ),
                ],
              ),
            ),
          );
        }

        // Show main screen if authenticated
        if (state is AuthAuthenticated) {
          return MainScreen();
        }

        // Show login screen if not authenticated
        return const LoginScreen();
      },
    );
  }
}
