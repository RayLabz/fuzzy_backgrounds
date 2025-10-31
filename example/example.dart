import 'package:flutter/material.dart';
import 'package:test_app/circles_background_screen.dart';
import 'package:test_app/gradient_background_screen.dart';
import 'package:test_app/orb_background_screen.dart';
import 'package:test_app/rays_background_screen.dart';
import 'package:test_app/ribbon_background_screen.dart';
import 'aurora_background_screen.dart';
import 'flowfield_background_screen.dart';

class BackgroundsScreen extends StatefulWidget {
  const BackgroundsScreen({super.key});

  @override
  State<BackgroundsScreen> createState() => _BackgroundsScreenState();
}

class _BackgroundsScreenState extends State<BackgroundsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
          padding: EdgeInsetsGeometry.all(18),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  ElevatedButton(
                      child: Text("Gradient background"),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => GradientBackgroundScreen(),));
                      }
                  ),

                  ElevatedButton(
                      child: Text("Fuzzy circles background"),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CirclesBackgroundScreen(),));
                      }
                  ),

                  ElevatedButton(
                      child: Text("Bloomy orbs background"),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => OrbsBackgroundScreen(),));
                      }
                  ),

                  ElevatedButton(
                      child: Text("Ribbon background"),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => RibbonBackgroundScreen(),));
                      }
                  ),

                  ElevatedButton(
                      child: Text("Aurora background"),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AuroraBackgroundScreen(),));
                      }
                  ),

                  ElevatedButton(
                      child: Text("Rays background"),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => RaysBackgroundScreen(),));
                      }
                  ),

                  ElevatedButton(
                      child: Text("Flow field background"),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => FlowFieldBackgroundScreen(),));
                      }
                  ),

                ],
              ),
            ),
          ),
        )
    );
  }
}
