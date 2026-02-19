import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class VoiceFailure extends Failure {
  const VoiceFailure(super.message);
}

class ParsingFailure extends Failure {
  const ParsingFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
