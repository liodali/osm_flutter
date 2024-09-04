class UserTrackingOption {
  final bool initWithUserPosition;
  final bool enableTracking;
  final bool unFollowUser;

  const UserTrackingOption({
    this.enableTracking = false,
    this.unFollowUser = false,
  }) : initWithUserPosition = true;

  const UserTrackingOption.withoutUserPosition({
    this.enableTracking = false,
    this.unFollowUser = false,
  }) : initWithUserPosition = false;
}
