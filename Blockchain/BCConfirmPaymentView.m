//
//  BCConfirmPaymentView.m
//  Blockchain
//
//  Created by Kevin Wu on 10/2/15.
//  Copyright © 2015 Blockchain Luxembourg S.A. All rights reserved.
//

#import "BCConfirmPaymentView.h"
#import "NSNumberFormatter+Currencies.h"
#import "UIView+ChangeFrameAttribute.h"
#import "Blockchain-Swift.h"
#import "ContactTransaction.h"
#import "BCTotalAmountView.h"
#import "TransactionDetailDescriptionCell.h"

#define NUMBER_OF_ROWS 5
#define SPACING_TEXTVIEW 5.6f

const int cellRowFrom = 0;
const int cellRowTo = 1;
const int cellRowAmount = 3;
const int cellRowFee = 4;

@interface BCConfirmPaymentView () <UITableViewDelegate, UITableViewDataSource, DescriptionDelegate>
@property (nonatomic) NSString *from;
@property (nonatomic) NSString *to;
@property (nonatomic) uint64_t amount;
@property (nonatomic) uint64_t fee;
@property (nonatomic) BOOL surgeIsOccurring;
@property (nonatomic) ContactTransaction *contactTransaction;

@end
@implementation BCConfirmPaymentView

- (id)initWithWindow:(UIView *)window
                from:(NSString *)from
                  To:(NSString *)to
              amount:(uint64_t)amount
                 fee:(uint64_t)fee
               total:(uint64_t)total
         contactTransaction:(ContactTransaction *)contactTransaction
               surge:(BOOL)surgePresent
{
    self = [super initWithFrame:CGRectMake(0, DEFAULT_HEADER_HEIGHT, window.frame.size.width, window.frame.size.height - DEFAULT_HEADER_HEIGHT)];
    
    if (self) {

        self.numberOfRows = NUMBER_OF_ROWS;
        
        [self setupPaymentButton];
        
        BCTotalAmountView *totalAmountView = [[BCTotalAmountView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, TOTAL_AMOUNT_VIEW_HEIGHT) color:COLOR_BLOCKCHAIN_RED amount:total];
        [self addSubview:totalAmountView];
        self.topView = totalAmountView;
        
        CGFloat tableViewHeight = CELL_HEIGHT * self.numberOfRows;
        
        self.from = from;
        self.to = to;
        self.amount = amount;
        self.fee = fee;
        self.contactTransaction = contactTransaction;
        self.surgeIsOccurring = surgePresent;
        
        self.backgroundColor = [UIColor whiteColor];
        
        UITableView *summaryTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, totalAmountView.frame.origin.y + totalAmountView.frame.size.height, window.frame.size.width, tableViewHeight)];
        summaryTableView.delegate = self;
        summaryTableView.dataSource = self;
        summaryTableView.tableFooterView = [UIView new];
        [summaryTableView registerClass:[TransactionDetailDescriptionCell class] forCellReuseIdentifier:CELL_IDENTIFIER_TRANSACTION_DETAIL_DESCRIPTION];
        [self addSubview:summaryTableView];
        
        self.tableView = summaryTableView;
    }
    return self;
}

- (void)setupPaymentButton
{
    CGFloat buttonHeight = 40;
    CGRect buttonFrame = CGRectMake(0, app.window.frame.size.height - DEFAULT_HEADER_HEIGHT - buttonHeight, app.window.frame.size.width, buttonHeight);;
    NSString *buttonTitle;
    
    if (self.contactTransaction) {
        buttonTitle = [self.contactTransaction.role isEqualToString:TRANSACTION_ROLE_RPR_INITIATOR] ? BC_STRING_SEND : BC_STRING_PAY;
    } else {
        buttonTitle = BC_STRING_SEND;
    }
    
    self.reallyDoPaymentButton = [[UIButton alloc] initWithFrame:CGRectZero];
    self.reallyDoPaymentButton.frame = buttonFrame;
    [self.reallyDoPaymentButton setTitle:buttonTitle forState:UIControlStateNormal];
    self.reallyDoPaymentButton.backgroundColor = COLOR_BLOCKCHAIN_LIGHT_BLUE;
    self.reallyDoPaymentButton.titleLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:17.0];
    
    [self.reallyDoPaymentButton addTarget:self action:@selector(reallyDoPaymentButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    
    [self addSubview:self.reallyDoPaymentButton];
}

#pragma mark - Actions

- (void)cancelEditing
{
    self.note = self.textView.text;

    CGFloat descriptionCellHeight = self.textView.frame.size.height + SPACING_TEXTVIEW * 2;
    
    [self.tableView changeHeight:(self.numberOfRows - 1) * CELL_HEIGHT + descriptionCellHeight];
    [self.tableView scrollRectToVisible:CGRectZero animated:YES];
    
    [super cancelEditing];
}

- (void)reallyDoPaymentButtonClicked
{
    if (!self.contactTransaction) {
        [self.delegate setupNoteForTransaction:self.textView.text];
    }
}

- (void)feeInformationButtonClicked
{
    [self.delegate feeInformationButtonClicked];
}

- (void)hideKeyboard
{
    [self.textView resignFirstResponder];
}

#pragma mark - Text Helpers

- (NSString *)formatAmountInBTCAndFiat:(uint64_t)amount
{
    return [NSString stringWithFormat:@"%@ (%@)", [NSNumberFormatter formatMoney:amount localCurrency:NO], [NSNumberFormatter formatMoney:amount localCurrency:YES]];
}

#pragma mark - Table View Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == cellRowDescription && self.textView.text) {
        return UITableViewAutomaticDimension;
    }
    return CELL_HEIGHT;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return NUMBER_OF_ROWS;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UIFont *mainFont = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    UIFont *detailFont = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    
    cell.textLabel.textColor = COLOR_TEXT_DARK_GRAY;
    cell.textLabel.font = mainFont;
    cell.detailTextLabel.textColor = COLOR_TEXT_DARK_GRAY;
    cell.detailTextLabel.font = detailFont;
    
    if (indexPath.row == cellRowTo) {
        cell.textLabel.text = BC_STRING_TO;
        cell.detailTextLabel.text = self.to;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    } else if (indexPath.row == cellRowFrom) {
        cell.textLabel.text = BC_STRING_FROM;
        cell.detailTextLabel.text = self.from;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    } else if (indexPath.row == cellRowAmount) {
        cell.textLabel.text = BC_STRING_AMOUNT;
        cell.detailTextLabel.text = [self formatAmountInBTCAndFiat:self.amount];
    } else if (indexPath.row == cellRowFee) {
        cell.textLabel.text = BC_STRING_FEE;
        cell.detailTextLabel.text = [self formatAmountInBTCAndFiat:self.fee];
        
        UILabel *testLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        testLabel.textColor = COLOR_TEXT_DARK_GRAY;
        testLabel.font = mainFont;
        testLabel.text = BC_STRING_FEE;
        [testLabel sizeToFit];
        
        self.feeInformationButton = [[UIButton alloc] initWithFrame:CGRectMake(15 + testLabel.frame.size.width + 8, 0, 19, 19)];
        [self.feeInformationButton setImage:[[UIImage imageNamed:@"help"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        self.feeInformationButton.tintColor = COLOR_BLOCKCHAIN_LIGHT_BLUE;
        self.feeInformationButton.center = CGPointMake(self.feeInformationButton.center.x, cell.contentView.center.y);
        [self.feeInformationButton addTarget:self action:@selector(feeInformationButtonClicked) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:self.feeInformationButton];
        
        if (self.surgeIsOccurring) cell.detailTextLabel.textColor = COLOR_WARNING_RED;
    } else if (indexPath.row == cellRowDescription) {
        TransactionDetailDescriptionCell *descriptionCell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER_TRANSACTION_DETAIL_DESCRIPTION forIndexPath:indexPath];
        descriptionCell.userInteractionEnabled = !self.contactTransaction;
        descriptionCell.descriptionDelegate = self;
        ; // use constant to get ideal cell height
        
        Transaction *transactionWithNote = [Transaction new];
        transactionWithNote.note = self.note;
        CGFloat spacing = SPACING_TEXTVIEW;
        [descriptionCell configureWithTransaction:transactionWithNote spacing:spacing];
        descriptionCell.mainLabel.font = mainFont;
        descriptionCell.textViewPlaceholderLabel.font = detailFont;
        descriptionCell.textView.font = detailFont;
        self.textView = descriptionCell.textView;
        descriptionCell.textView.inputAccessoryView = [self getDescriptionInputAccessoryView];
        return descriptionCell;
    }
    return cell;
}

@end
