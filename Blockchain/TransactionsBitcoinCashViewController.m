//
//  TransactionsBitcoinCashViewController.m
//  Blockchain
//
//  Created by kevinwu on 2/21/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

#import "TransactionsBitcoinCashViewController.h"
#import "RootService.h"
#import "NSNumberFormatter+Currencies.h"
#import "TransactionTableCell.h"
#import "Transaction.h"

@interface TransactionsViewController ()
@property (nonatomic) UILabel *noTransactionsTitle;
@property (nonatomic) UILabel *noTransactionsDescription;
@property (nonatomic) UIButton *getBitcoinButton;
@property (nonatomic) UIView *noTransactionsView;
- (void)setupNoTransactionsViewInView:(UIView *)view assetType:(AssetType)assetType;
@end

@interface TransactionsBitcoinCashViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) NSArray *transactions;
@end

@implementation TransactionsBitcoinCashViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.frame = CGRectMake(0,
                                 DEFAULT_HEADER_HEIGHT_OFFSET,
                                 [UIScreen mainScreen].bounds.size.width,
                                 [UIScreen mainScreen].bounds.size.height - DEFAULT_HEADER_HEIGHT - DEFAULT_HEADER_HEIGHT_OFFSET - DEFAULT_FOOTER_HEIGHT);
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];
    
    [self setupPullToRefresh];

    [self setupNoTransactionsViewInView:self.tableView assetType:AssetTypeBitcoinCash];

    [self loadTransactions];
}

- (void)setupPullToRefresh
{
    // Tricky way to get the refreshController to work on a UIViewController - @see http://stackoverflow.com/a/12502450/2076094
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(getHistory)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
}

- (void)loadTransactions
{
    self.transactions = [app.wallet getBitcoinCashTransactions];
    
    self.noTransactionsView.hidden = self.transactions.count > 0;
    
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (void)reload
{
    [self loadTransactions];
}

- (void)getHistory
{
    [app showBusyViewWithLoadingText:BC_STRING_LOADING_LOADING_TRANSACTIONS];

    [app.wallet performSelector:@selector(getBitcoinCashHistory) withObject:nil afterDelay:0.1f];
}

#pragma mark - Table View Data Source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TransactionTableCell * cell = (TransactionTableCell*)[tableView dequeueReusableCellWithIdentifier:@"transaction"];
    
    Transaction * transaction = [self.transactions objectAtIndex:[indexPath row]];

    if (cell == nil) {
        cell = [[[NSBundle mainBundle] loadNibNamed:@"TransactionCell" owner:nil options:nil] objectAtIndex:0];
    }
    
    cell.transaction = transaction;
    
    [cell reload];
    
    [cell changeBtcButtonTitleText:[NSNumberFormatter formatBchWithSymbol:ABS(transaction.amount)]];
    
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    cell.selectedBackgroundView = [self selectedBackgroundViewForCell:cell];
    
    return cell;
}

- (UIView *)selectedBackgroundViewForCell:(UITableViewCell *)cell
{
    // Selected cell color
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0,0,cell.frame.size.width,cell.frame.size.height)];
    [v setBackgroundColor:COLOR_BLOCKCHAIN_BLUE];
    return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 65;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.transactions.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    TransactionTableCell *cell = (TransactionTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    
    [cell bitcoinCashTransactionClicked];
}

@end
