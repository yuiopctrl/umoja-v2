import 'app_routes.dart';

/// Member self-service child routes (`/me/...`), shared by
/// [route_guard.dart] (the authorization boundary's UX guidance) and
/// [app_shell.dart] (navigation chrome and bottom-bar selection), so the
/// two can never drift apart — Prompt 09G-B5-C.2 §G: "More navigation
/// and RouteGuard must derive from the same effective permission state
/// so an item cannot be visible but route-blocked, or route-allowed but
/// invisible."
bool isMyProfileRoute(String location) => location == AppRoutes.myProfile;

bool isMyStatementRoute(String location) => location == AppRoutes.myStatement;

bool isMyContributionsRoute(String location) =>
    location == AppRoutes.myContributions ||
    location.startsWith('${AppRoutes.myContributions}/');

bool isMyLoansRoute(String location) =>
    location == AppRoutes.myLoans ||
    location.startsWith('${AppRoutes.myLoans}/');

/// Any member self-service child route — the set that shares one
/// compact header and that the bottom/sidebar navigation treats as
/// "within More", never as Home (Prompt 09G-B5-C.2 §I).
bool isMemberSelfServiceChildRoute(String location) =>
    isMyProfileRoute(location) ||
    isMyStatementRoute(location) ||
    isMyContributionsRoute(location) ||
    isMyLoansRoute(location);
