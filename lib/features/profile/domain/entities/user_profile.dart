import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String? displayName;
  final String email;
  final String? avatarUrl;
  final String? phone;
  final String? bio;
  final String currencyPreference;
  final int currencyChangeCount;
  final int currencyChangeYear;
  final bool isPremium;
  final bool isSetupComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.displayName,
    required this.email,
    this.avatarUrl,
    this.phone,
    this.bio,
    this.currencyPreference = 'USD',
    this.currencyChangeCount = 0,
    this.currencyChangeYear = 1970,
    this.isPremium = false,
    this.isSetupComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? phone,
    String? bio,
    String? currencyPreference,
    int? currencyChangeCount,
    int? currencyChangeYear,
    bool? isPremium,
    bool? isSetupComplete,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      currencyPreference: currencyPreference ?? this.currencyPreference,
      currencyChangeCount: currencyChangeCount ?? this.currencyChangeCount,
      currencyChangeYear: currencyChangeYear ?? this.currencyChangeYear,
      isPremium: isPremium ?? this.isPremium,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      currencyPreference: json['currency_preference'] as String? ?? 'USD',
      currencyChangeCount: json['currency_change_count'] as int? ?? 0,
      currencyChangeYear:
          json['currency_change_year'] as int? ?? DateTime.now().year,
      isPremium: json['is_premium'] as bool? ?? false,
      isSetupComplete: json['is_setup_complete'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'avatar_url': avatarUrl,
      'phone': phone,
      'bio': bio,
      'currency_preference': currencyPreference,
      'currency_change_count': currencyChangeCount,
      'currency_change_year': currencyChangeYear,
      'is_premium': isPremium,
      'is_setup_complete': isSetupComplete,
    };
  }

  @override
  List<Object?> get props => [
    id,
    displayName,
    email,
    avatarUrl,
    phone,
    bio,
    currencyPreference,
    currencyChangeCount,
    currencyChangeYear,
    isPremium,
    isSetupComplete,
  ];
}
