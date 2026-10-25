// One build for the focused signup suite and native screen review.
import 'signup_suite_local_test.dart' as regression;
import 'signup_screens_review_test.dart' as screens;

void main() {
  regression.main();
  screens.main();
}
