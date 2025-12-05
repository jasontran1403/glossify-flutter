import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/sign_in/sign_in.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<CreateAccountScreen> {
  TextEditingController usernamecontroller = TextEditingController();
  TextEditingController emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();
  bool isChecked = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                SizedBox(height: 5),
                Center(
                  child: Text(
                    'Fill your information below',
                    style: TextStyle(fontSize: 14, color: AppColors.mistBlueColor),
                  ),
                ),
                SizedBox(height: 30),
                Text('Name'),
                TextField(
                  controller: usernamecontroller,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'John Doe',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),
                SizedBox(height: 10),
                Text('Email'),
                TextField(
                  controller: emailcontroller,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Example@gmail.com',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  obscureText: true,
                ),SizedBox(height: 10),
                Text('Password'),
                TextField(
                  controller: passwordcontroller,
                  decoration: InputDecoration(
                    // suffixIcon: Icon(Icons.remove_red_eye),
                    border: OutlineInputBorder(),
                    hintText: '********',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: isChecked,
                    activeColor:AppColors.primaryColor,
                      onChanged: (value) {
                        setState(() {
                          isChecked = value!;
                        });
                      },
                    ),
                    Text("Agree with Terms & Condition"),
                  ],
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    if (usernamecontroller.text.isNotEmpty && passwordcontroller.text.isNotEmpty) {
                      Navigation.pushReplacement(context, const SignInScreen());}
                    else{
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Please enter Both Field'),
                          duration: const Duration(seconds: 3),
                          backgroundColor:AppColors.primaryColor
                      ));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: AppColors.primaryColor,
                    ),
                    child: SizedBox(
                      height: 45,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 18, color: AppColors.whiteColor),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 35),
                Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Or Sign Up With'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                SizedBox(height: 35),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.blackColor, width: 1),
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.whiteColor,
                        child: ClipOval(
                          child: Image.asset(
                            AppImages.apple,
                            height: 28,
                            width: 28,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.blackColor, width: 1),
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.whiteColor,
                        child: ClipOval(
                          child: Image.asset(
                            AppImages.google,
                            height: 28,
                            width: 28,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.blackColor, width: 1),
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.whiteColor,
                        child: ClipOval(
                          child: Image.asset(
                            AppImages.facebook,
                            height: 28,
                            width: 28,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 35),
                Center(
                  child:GestureDetector(
                    onTap: (){
                      Navigation.pop(context);
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'If You Have Account?',style: TextStyle(color: AppColors.blackColor,),
                        children: const <TextSpan>[
                          TextSpan(text: '  sign In ', style: TextStyle(color: AppColors.primaryColor)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
