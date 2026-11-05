import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/services/security_service.dart';
import '../features/advances/presentation/advance_ledger_screen.dart';
import '../features/auth/presentation/lock_screen.dart';
import '../features/billing/presentation/bill_detail_screen.dart';
import '../features/billing/presentation/bill_list_screen.dart';
import '../features/billing/presentation/generate_bill_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/electricity/presentation/electricity_allocation_screen.dart';
import '../features/electricity/presentation/electricity_screen.dart';
import '../features/electricity/presentation/meter_reading_screen.dart';
import '../features/expenses/presentation/add_expense_screen.dart';
import '../features/expenses/presentation/expense_list_screen.dart';
import '../features/payments/presentation/payment_list_screen.dart';
import '../features/payments/presentation/record_payment_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/rooms/presentation/add_edit_room_screen.dart';
import '../features/rooms/presentation/room_detail_screen.dart';
import '../features/rooms/presentation/room_list_screen.dart';
import '../features/settings/presentation/backup_restore_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tenants/presentation/add_edit_tenant_screen.dart';
import '../features/tenants/presentation/assign_tenancy_screen.dart';
import '../features/tenants/presentation/tenant_detail_screen.dart';
import '../features/tenants/presentation/tenant_list_screen.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;

  const MainScaffold({Key? key, required this.child}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/rooms')) return 1;
    if (location.startsWith('/tenants')) return 2;
    if (location.startsWith('/bills')) return 3;
    if (location.startsWith('/more') ||
        location.startsWith('/electricity') ||
        location.startsWith('/payments') ||
        location.startsWith('/expenses') ||
        location.startsWith('/reports') ||
        location.startsWith('/settings')) {
      return 4;
    }
    return 0; // Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/rooms');
        break;
      case 2:
        context.go('/tenants');
        break;
      case 3:
        context.go('/bills');
        break;
      case 4:
        _showMoreMenu(context);
        break;
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.bolt, color: Colors.amber),
                  title: const Text('Electricity & Meter Readings'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/electricity');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined, color: Colors.green),
                  title: const Text('Payment Receipts'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/payments');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_outlined, color: Colors.red),
                  title: const Text('Property Expenses'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/expenses');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart, color: Colors.blue),
                  title: const Text('Financial Reports'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/reports');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: Colors.grey),
                  title: const Text('Settings & Backup'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (idx) => _onItemTapped(idx, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Tenants',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/initial',
  routes: [
    GoRoute(
      path: '/initial',
      redirect: (context, state) async {
        final pinEnabled = await SecurityService.isPinEnabled();
        return pinEnabled ? '/lock' : '/dashboard';
      },
    ),
    GoRoute(
      path: '/lock',
      builder: (context, state) => const LockScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/rooms',
          builder: (context, state) => const RoomListScreen(),
        ),
        GoRoute(
          path: '/tenants',
          builder: (context, state) => const TenantListScreen(),
        ),
        GoRoute(
          path: '/bills',
          builder: (context, state) => const BillListScreen(),
        ),
      ],
    ),
    // Non-shell nested routes
    GoRoute(
      path: '/rooms/add',
      builder: (context, state) => const AddEditRoomScreen(),
    ),
    GoRoute(
      path: '/rooms/:id',
      builder: (context, state) => RoomDetailScreen(roomId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/rooms/:id/edit',
      builder: (context, state) => AddEditRoomScreen(roomId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tenants/add',
      builder: (context, state) => const AddEditTenantScreen(),
    ),
    GoRoute(
      path: '/tenants/assign',
      builder: (context, state) {
        final roomId = state.uri.queryParameters['roomId'];
        final tenantId = state.uri.queryParameters['tenantId'];
        return AssignTenancyScreen(preselectedRoomId: roomId, preselectedTenantId: tenantId);
      },
    ),
    GoRoute(
      path: '/tenants/:id',
      builder: (context, state) => TenantDetailScreen(tenantId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tenants/:id/advances',
      builder: (context, state) {
        final tenancyId = state.uri.queryParameters['tenancyId'] ?? '';
        final accountType = state.uri.queryParameters['accountType'];
        return AdvanceLedgerScreen(
          tenancyId: tenancyId,
          tenantName: 'Tenant Advances',
          initialAccountType: accountType,
        );
      },
    ),
    GoRoute(
      path: '/tenants/:id/edit',
      builder: (context, state) => AddEditTenantScreen(tenantId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/electricity',
      builder: (context, state) => const ElectricityScreen(),
    ),
    GoRoute(
      path: '/electricity/record',
      builder: (context, state) => MeterReadingScreen(preselectedMeterId: state.uri.queryParameters['meterId']),
    ),
    GoRoute(
      path: '/electricity/allocate',
      builder: (context, state) => const ElectricityAllocationScreen(),
    ),
    GoRoute(
      path: '/bills/generate',
      builder: (context, state) => GenerateBillScreen(preselectedRoomId: state.uri.queryParameters['roomId']),
    ),
    GoRoute(
      path: '/bills/:id',
      builder: (context, state) => BillDetailScreen(billId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/payments',
      builder: (context, state) => const PaymentListScreen(),
    ),
    GoRoute(
      path: '/payments/record',
      builder: (context, state) {
        return RecordPaymentScreen(
          preselectedTenancyId: state.uri.queryParameters['tenancyId'],
          preselectedBillId: state.uri.queryParameters['billId'],
          prefilledRentAmountPaise: state.uri.queryParameters['rentAmount'],
          prefilledElecAmountPaise: state.uri.queryParameters['elecAmount'],
          prefilledAmountPaise: state.uri.queryParameters['amount'],
          preselectedRoomId: state.uri.queryParameters['roomId'],
        );
      },
    ),
    GoRoute(
      path: '/expenses',
      builder: (context, state) => const ExpenseListScreen(),
    ),
    GoRoute(
      path: '/expenses/add',
      builder: (context, state) => const AddExpenseScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/backup',
      builder: (context, state) => const BackupRestoreScreen(),
    ),
  ],
);
