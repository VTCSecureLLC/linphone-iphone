/* UIContactDetailsHeader.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Library General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "UIContactDetailsHeader.h"
#import "Utils.h"
#import "UIEditableTableViewCell.h"
#import "FastAddressBook.h"
#import "UILinphone.h"
#import "PhoneMainView.h"
#import "DTActionSheet.h"
#import <MobileCoreServices/UTCoreTypes.h>

@implementation UIContactDetailsHeader

@synthesize avatarImage;
@synthesize addressLabel;
@synthesize contact;
@synthesize normalView;
@synthesize editView;
@synthesize tableView;
@synthesize contactDetailsDelegate;
@synthesize popoverController;
@synthesize toggleFavoriteButton;
#pragma mark - Lifecycle Functions

- (void)initUIContactDetailsHeader {
	propertyList = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:kABPersonFirstNameProperty],
													[NSNumber numberWithInt:kABPersonLastNameProperty],
													[NSNumber numberWithInt:kABPersonOrganizationProperty], nil];
	editing = FALSE;
}

- (id)init {
	self = [super init];
	if (self != nil) {
		[self initUIContactDetailsHeader];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self != nil) {
		[self initUIContactDetailsHeader];
	}
	return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self != nil) {
		[self initUIContactDetailsHeader];
	}
	return self;
}

#pragma mark - ViewController Functions

- (void)viewDidLoad {
	[super viewDidLoad];
	[tableView setBackgroundColor:[UIColor clearColor]]; // Can't do it in Xib: issue with ios4
	[tableView setBackgroundView:nil];					 // Can't do it in Xib: issue with ios4
	[normalView setAlpha:1.0f];
	[editView setAlpha:0.0f];
	[tableView setEditing:TRUE animated:false];
	tableView.accessibilityIdentifier = @"Contact Name Table";
}

#pragma mark - Propery Functions

- (void)setContact:(ABRecordRef)acontact {
	contact = acontact;
	[self update];
}

#pragma mark -

- (BOOL)isValid {
	for (int i = 0; i < [propertyList count]; ++i) {
		UIEditableTableViewCell *cell =
			(UIEditableTableViewCell *)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
		if ([cell.detailTextField.text length] > 0)
			return true;
	}
	return false;
}

- (void)update {
	if (contact == NULL) {
		LOGW(@"Cannot update contact details header: null contact");
		return;
	}

	// Avatar image
	{
		UIImage *image = [FastAddressBook getContactImage:contact thumbnail:false];
		if (image == nil) {
			image = [UIImage imageNamed:@"avatar_unknown_small.png"];
		}
		[avatarImage setImage:image];
	}

	// Contact label
	{ [addressLabel setText:[FastAddressBook getContactDisplayName:contact]]; }
   
    NSArray *favorites = [ContactFavoritesManager getFavorites];
    if([favorites containsObject:[NSNumber numberWithInt:ABRecordGetRecordID(contact)]]){
       
        [toggleFavoriteButton setSelected:YES];
    }
    else{
       
        [toggleFavoriteButton setSelected:NO];
    }

    
    
	[tableView reloadData];
}

+ (CGFloat)height:(BOOL)editing {
	if (editing) {
		return 170.0f;
	} else {
		return 80.0f;
	}
}

- (void)setEditing:(BOOL)aediting animated:(BOOL)animated {
	editing = aediting;
	// Resign keyboard
	if (!editing) {
		[LinphoneUtils findAndResignFirstResponder:[self tableView]];
		[self update];
	}
	if (animated) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.3];
	}
	if (editing) {
		[editView setAlpha:1.0f];
		[normalView setAlpha:0.0f];
	} else {
		[editView setAlpha:0.0f];
		[normalView setAlpha:1.0f];
	}
	if (animated) {
		[UIView commitAnimations];
	}
}

- (void)setEditing:(BOOL)aediting {
	[self setEditing:aediting animated:FALSE];
}

- (BOOL)isEditing {
	return editing;
}

- (void)updateModification {
	[contactDetailsDelegate onModification:nil];
}

#pragma mark - UITableViewDataSource Functions

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [propertyList count];
}

- (UITableViewCell *)tableView:(UITableView *)atableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *kCellId = @"ContactDetailsHeaderCell";
	UIEditableTableViewCell *cell = [atableView dequeueReusableCellWithIdentifier:kCellId];
	if (cell == nil) {
		cell = [[UIEditableTableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:kCellId];
		[cell.detailTextField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
		[cell.detailTextField setAutocorrectionType:UITextAutocorrectionTypeNo];
		[cell.detailTextField setKeyboardType:UIKeyboardTypeDefault];
        [cell setBackgroundColor:[UIColor whiteColor]];
	}

	// setup placeholder
	ABPropertyID property = [[propertyList objectAtIndex:[indexPath row]] intValue];
	if (property == kABPersonFirstNameProperty) {
		[cell.detailTextField setPlaceholder:NSLocalizedString(@"First name", nil)];
	} else if (property == kABPersonLastNameProperty) {
		[cell.detailTextField setPlaceholder:NSLocalizedString(@"Last name", nil)];
	} else if (property == kABPersonOrganizationProperty) {
		[cell.detailTextField setPlaceholder:NSLocalizedString(@"Company name", nil)];
	}

	[cell.detailTextField setKeyboardType:UIKeyboardTypeDefault];

	// setup values, if they exist
	if (contact) {
		NSString *lValue = CFBridgingRelease(ABRecordCopyValue(contact, property));
		if (lValue != NULL) {
			[cell.detailTextLabel setText:lValue];
			[cell.detailTextField setText:lValue];
		} else {
			[cell.detailTextLabel setText:@""];
			[cell.detailTextField setText:@""];
		}
	}
	[cell.detailTextField setDelegate:self];

	return cell;
}

#pragma mark - Action Functions

- (IBAction)onAvatarClick:(id)event {
	if (self.isEditing) {
		void (^showAppropriateController)(UIImagePickerControllerSourceType) =
			^(UIImagePickerControllerSourceType type) {
			  UICompositeViewDescription *description = [ImagePickerViewController compositeViewDescription];
			  ImagePickerViewController *controller;
			  if ([LinphoneManager runningOnIpad]) {
				  controller = DYNAMIC_CAST(
					  [[PhoneMainView instance].mainViewController getCachedController:description.content],
					  ImagePickerViewController);
				  // keep a reference to this controller so that in case of memory pressure we keep it
				  self.popoverController = controller;
			  } else {
				  controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:description push:TRUE],
											ImagePickerViewController);
			  }
			  if (controller != nil) {
				  controller.sourceType = type;

				  // Displays a control that allows the user to choose picture or
				  // movie capture, if both are available:
				  controller.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];

				  // Hides the controls for moving & scaling pictures, or for
				  // trimming movies. To instead show the controls, use YES.
				  controller.allowsEditing = NO;
				  controller.imagePickerDelegate = self;

				  if ([LinphoneManager runningOnIpad]) {
					  [controller.popoverController presentPopoverFromRect:[avatarImage frame]
																	inView:self.view
												  permittedArrowDirections:UIPopoverArrowDirectionAny
																  animated:FALSE];
				  }
			  }
			};
		DTActionSheet *sheet = [[DTActionSheet alloc] initWithTitle:NSLocalizedString(@"Select picture source", nil)];
		if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
			[sheet addButtonWithTitle:NSLocalizedString(@"Camera", nil)
								block:^() {
								  showAppropriateController(UIImagePickerControllerSourceTypeCamera);
								}];
		}
		if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
			[sheet addButtonWithTitle:NSLocalizedString(@"Photo library", nil)
								block:^() {
								  showAppropriateController(UIImagePickerControllerSourceTypePhotoLibrary);
								}];
		}
		if ([FastAddressBook getContactImage:contact thumbnail:true] != nil) {
			[sheet addDestructiveButtonWithTitle:NSLocalizedString(@"Remove", nil)
										   block:^() {
											 CFErrorRef error = NULL;
											 if (!ABPersonRemoveImageData(contact, (CFErrorRef *)&error)) {
												 LOGI(@"Can't remove entry: %@",
													  [(__bridge NSError *)error localizedDescription]);
											 }
											 [self update];
										   }];
		}
		[sheet addCancelButtonWithTitle:NSLocalizedString(@"Cancel", nil)
								  block:^{
									self.popoverController = nil;
								  }];

		[sheet showInView:[PhoneMainView instance].view];
	}
}

#pragma mark - ContactDetailsImagePickerDelegate Functions

- (void)imagePickerDelegateImage:(UIImage *)image info:(NSDictionary *)info {
	// Dismiss popover on iPad
	if ([LinphoneManager runningOnIpad]) {
		UICompositeViewDescription *description = [ImagePickerViewController compositeViewDescription];
		ImagePickerViewController *controller =
			DYNAMIC_CAST([[PhoneMainView instance].mainViewController getCachedController:description.content],
						 ImagePickerViewController);
		if (controller != nil) {
			[controller.popoverController dismissPopoverAnimated:TRUE];
			self.popoverController = nil;
		}
	}
	FastAddressBook *fab = [LinphoneManager instance].fastAddressBook;
	CFErrorRef error = NULL;
	if (!ABPersonRemoveImageData(contact, (CFErrorRef *)&error)) {
		LOGI(@"Can't remove entry: %@", [(__bridge NSError *)error localizedDescription]);
	}
	NSData *dataRef = UIImageJPEGRepresentation(image, 0.9f);
	CFDataRef cfdata = CFDataCreate(NULL, [dataRef bytes], [dataRef length]);

	[fab saveAddressBook];

	if (!ABPersonSetImageData(contact, cfdata, (CFErrorRef *)&error)) {
		LOGI(@"Can't add entry: %@", [(__bridge NSError *)error localizedDescription]);
	} else {
		[fab saveAddressBook];
	}

	CFRelease(cfdata);

	[self update];
}

#pragma mark - UITableViewDelegate Functions

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleNone;
}

#pragma mark - UITextFieldDelegate Functions

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (BOOL)textField:(UITextField *)textField
	shouldChangeCharactersInRange:(NSRange)range
				replacementString:(NSString *)string {
	if (contactDetailsDelegate != nil) {
		// add a mini delay to have the text updated BEFORE notifying the selector
		[self performSelector:@selector(updateModification) withObject:nil afterDelay:0.1];
	}
	return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
	UIView *view = [textField superview];
	// Find TableViewCell
	while (view != nil && ![view isKindOfClass:[UIEditableTableViewCell class]])
		view = [view superview];

	if (view != nil) {
		UIEditableTableViewCell *cell = (UIEditableTableViewCell *)view;
		NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
		ABPropertyID property = [[propertyList objectAtIndex:[indexPath row]] intValue];
		[cell.detailTextLabel setText:[textField text]];
		CFErrorRef error = NULL;
		ABRecordSetValue(contact, property, (__bridge CFTypeRef)([textField text]), (CFErrorRef *)&error);
		if (error != NULL) {
			LOGE(@"Error when saving property %i in contact %p: Fail(%@)", property, contact,
				 [(__bridge NSError *)error localizedDescription]);
		}
	} else {
		LOGW(@"Not valid UIEditableTableViewCell");
	}
	if (contactDetailsDelegate != nil) {
		// add a mini delay to have the text updated BEFORE notifying the selector
		[self performSelector:@selector(updateModification) withObject:nil afterDelay:0.1];
	}
	return TRUE;
}
- (IBAction)toggleFavorite:(id)sender {
    if(!contact) return;
    NSArray *favorites = [ContactFavoritesManager getFavorites];
    if([favorites containsObject:[NSNumber numberWithInt:ABRecordGetRecordID(contact)]]){
        [ContactFavoritesManager removeFavorite:ABRecordGetRecordID(contact)];
        [toggleFavoriteButton setSelected:NO];
    }
    else{
        [ContactFavoritesManager addFavorite:ABRecordGetRecordID(contact)];
       [toggleFavoriteButton setSelected:YES];
    }
}

@end
