import re

files_to_update = [
    'lib/providers/language_provider.dart',
    'lib/screens/settings_screen.dart',
    'lib/screens/verification_screen.dart',
    'lib/screens/chat_screen.dart',
    'lib/screens/notification_screen.dart',
]

for path in files_to_update:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Text replacements for user facing wording
    content = content.replace('Allow Booking Requests', 'Allow Meetup Requests')
    content = content.replace('Booking Settings', 'Meetup Settings')
    content = content.replace('Booking Details', 'Meetup Details')
    content = content.replace('Edit Booking Details', 'Edit Meetup Details')
    content = content.replace('My Bookings', 'My Meetups')
    content = content.replace('_otherUserAllowsBooking', '_otherUserAllowsMeetup')
    content = content.replace('_buildBookingSection', '_buildMeetupSection')
    content = content.replace('_showBookingPreferencesSheet', '_showMeetupPreferencesSheet')
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

print("Replacement complete.")
