import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String id;
  final String email;

  const AppUser({required this.id, required this.email});

  @override
  List<Object?> get props => [id, email];
}
