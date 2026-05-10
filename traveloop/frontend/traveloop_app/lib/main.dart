import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_colors.dart';

// Each member imports their own screen files here
void main() => runApp(TraveloopApp());

class TraveloopApp extends StatelessWidget {
  final _router = GoRouter(routes: [
    GoRoute(path: '/', builder: (c, s) => LoginScreen()),
    GoRoute(path: '/dashboard', builder: (c, s) => DashboardScreen()),
    GoRoute(path: '/trips', builder: (c, s) => MyTripsScreen()),
    GoRoute(path: '/trips/create', builder: (c, s) => CreateTripScreen()),
    GoRoute(path: '/itinerary/:tripId', builder: (c, s) => ItineraryBuilderScreen(tripId: int.parse(s.pathParameters['tripId']!))),
    GoRoute(path: '/itinerary/:tripId/view', builder: (c, s) => ItineraryViewScreen(tripId: int.parse(s.pathParameters['tripId']!))),
    GoRoute(path: '/budget/:tripId', builder: (c, s) => BudgetScreen(tripId: int.parse(s.pathParameters['tripId']!))),
    GoRoute(path: '/checklist/:tripId', builder: (c, s) => ChecklistScreen(tripId: int.parse(s.pathParameters['tripId']!))),
    GoRoute(path: '/share/:slug', builder: (c, s) => SharedTripScreen(slug: s.pathParameters['slug']!)),
    GoRoute(path: '/profile', builder: (c, s) => ProfileScreen()),
    GoRoute(path: '/notes/:tripId', builder: (c, s) => NotesScreen(tripId: int.parse(s.pathParameters['tripId']!))),
    GoRoute(path: '/admin', builder: (c, s) => AdminDashboardScreen()),
  ]);

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        routerConfig: _router,
        title: 'Traveloop',
        theme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Poppins',
        ),
      );
}   