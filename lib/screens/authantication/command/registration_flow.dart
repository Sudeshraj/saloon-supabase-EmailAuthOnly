import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/authantication/models/user.dart';
import 'package:flutter_application_1/screens/authantication/command/email_screen.dart';
import 'package:flutter_application_1/screens/authantication/business_reg/company_name_screen.dart';
import 'package:flutter_application_1/screens/authantication/customer_reg/name_screen.dart';
import 'package:flutter_application_1/screens/authantication/command/finish_screen.dart';
import 'package:flutter_application_1/screens/authantication/command/password_screen.dart';
import 'package:flutter_application_1/screens/authantication/command/welcome.dart';
// import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/screens/authantication/services/registration_service.dart';

class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({super.key});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  final PageController _controller = PageController();

  // ---- UPDATED ROLE SYSTEM ----
  List<String> roles = [];

  // ---- Common fields ----
  String? firstName;
  String? lastName;
  String? email;
  String? password;


  // ---- Business fields ----
  String? companyName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // 👉 SELECT ROLE (customer / business)
          WelcomeScreen(
            onNext: (type) {
              setState(() {
                roles = [type]; // ADD FIRST ROLE INTO LIST
              });
              _nextPage();
            },
          ),

          // 👉 CUSTOMER REGISTRATION FLOW
          if (roles.contains('customer')) ..._buildCustomerFlow(),

          // 👉 BUSINESS REGISTRATION FLOW
          if (roles.contains('business')) ..._buildBusinessFlow(),
        ],
      ),
    );
  }

  // ------------------- CUSTOMER FLOW -------------------
  List<Widget> _buildCustomerFlow() => [
        NameEntry(
          onNext: (f, l) {
            setState(() {
              firstName = f;
              lastName = l;
            });
            _nextPage();
          },
          controller: _controller,
        ),      
        EmailScreen(
          onNext: (e) {
            setState(() => email = e);
            _nextPage();
          },
          controller: _controller,
        ),
        PasswordScreen(
          onNext: (p) {
            setState(() => password = p);
            _nextPage();
          },
          controller: _controller,
        ),

        // ---------------- FINISH CUSTOMER SIGN UP ----------------
        FinishScreen(
          controller: _controller,
          onSignUp: () async {
            if (email == null || password == null) {
              throw Exception("Please complete all fields before signing up.");
            }

            final customerAuth = CustomerAuth(
              roles: roles,        // <-- UPDATED
              firstName: firstName!,
              lastName: lastName!,            
              email: email!,
              password: password!,
            );

            await SaveUser().saveUser(customerAuth, context);
          },
        ),
      ];

  // ------------------- BUSINESS FLOW -------------------
  List<Widget> _buildBusinessFlow() => [
        CompanyNameScreen(
          onNext: (n) {
            setState(() => companyName = n);
            _nextPage();
          },
          controller: _controller,
        ),      
        EmailScreen(
          onNext: (e) {
            setState(() => email = e);
            _nextPage();
          },
          controller: _controller,
        ),
        PasswordScreen(
          onNext: (p) {
            setState(() => password = p);
            _nextPage();
          },
          controller: _controller,
        ),

        // ---------------- FINISH BUSINESS SIGN UP ----------------
        FinishScreen(
          controller: _controller,
          onSignUp: () async {
            if (email == null || password == null ) {
              throw Exception("Please complete all fields before signing up.");
            }

            final companyAuth = CompanyAuth(
              roles: roles,            // <-- UPDATED
              companyName: companyName!,             
              email: email!,             
              password: password!,
            );

            await SaveUser().saveCompany(companyAuth, context);
          },
        ),
      ];

  void _nextPage() => _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
}
