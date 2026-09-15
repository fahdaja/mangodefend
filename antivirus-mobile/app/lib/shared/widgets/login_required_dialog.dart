import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/widgets/account_question_dialog.dart';

class LoginRequiredDialog extends StatelessWidget {
  final String? title;
  final String? description;
  final VoidCallback? onLoginPressed;
  final VoidCallback? onRegisterPressed;

  const LoginRequiredDialog({
    super.key,
    this.title,
    this.description,
    this.onLoginPressed,
    this.onRegisterPressed,
  });

  static void show(
    BuildContext context, {
    String? title,
    String? description,
    VoidCallback? onLoginPressed,
    VoidCallback? onRegisterPressed,
  }) {
    AccountQuestionDialog.show(
      context,
      title: title,
      description: description,
      onLoginPressed: onLoginPressed,
      onRegisterPressed: onRegisterPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccountQuestionDialog(
      title: title,
      description: description,
      onLoginPressed: onLoginPressed,
      onRegisterPressed: onRegisterPressed,
    );
  }
}
