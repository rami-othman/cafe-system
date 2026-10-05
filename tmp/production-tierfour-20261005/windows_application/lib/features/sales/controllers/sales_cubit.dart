import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/sales_repository.dart';
class SalesCubit extends Cubit<void> { SalesCubit({required this.repository}) : super(null); final SalesRepository repository; }
