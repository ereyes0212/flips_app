
import 'package:flips_app/providers/auth.provider.dart';
import 'package:provider/provider.dart';



resetProviders(context) {
  Provider.of<AuthProvider>(context, listen: false).resetProvider();
}
