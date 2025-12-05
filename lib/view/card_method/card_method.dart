// lib/view/card_method/card_method.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../api/gift_card_model.dart';

class CardMethodScreen extends StatefulWidget {
  const CardMethodScreen({super.key});

  @override
  State<CardMethodScreen> createState() => _CardMethodScreenState();
}

class _CardMethodScreenState extends State<CardMethodScreen> {
  List<UserGiftCard> _giftCards = [];
  bool _isLoadingCards = true;
  int _currentCardIndex = 0;
  final PageController _cardPageController = PageController();

  List<GiftCardTransaction> _transactions = [];
  bool _isLoadingTransactions = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 10;
  final double _loadThreshold = 200.0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadGiftCards();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _cardPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadThreshold) {
      _loadTransactions(isRefresh: false);
    }
  }

  Future<void> _loadGiftCards() async {
    try {
      final cards = await ApiService.getUserGiftCards();

      if (!mounted) return;

      setState(() {
        _giftCards = cards;
        _isLoadingCards = false;
      });

      if (_giftCards.isNotEmpty) {
        _loadTransactions(isRefresh: true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingCards = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading gift cards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isLoadingTransactionsGlobal = false;

  Future<void> _loadTransactions({required bool isRefresh}) async {
    if (_giftCards.isEmpty) {
      return;
    }

    // ✅ FIX: Block concurrent calls
    if (_isLoadingTransactionsGlobal) {
      return;
    }
    _isLoadingTransactionsGlobal = true;

    // Local vars để tránh race condition
    bool shouldRefresh = isRefresh;
    int currentPage = _page;
    String currentCode = _giftCards[_currentCardIndex].code;

    if (shouldRefresh) {
      setState(() {
        _isLoadingTransactions = true;
        _transactions.clear();
        _page = 0;  // Reset page
        _hasMore = true;
      });
      currentPage = 0;  // Sync local
    } else if (_isLoadingMore || !_hasMore) {
      _isLoadingTransactionsGlobal = false;  // Unlock ngay nếu skip
      return;
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {

      final result = await ApiService.getUserGiftCardTransactions(
        page: currentPage,
        size: _pageSize,
      );

      if (!mounted) {
        return;
      }

      final List<GiftCardTransaction> allTransactions = result['content'];
      final bool hasNextPage = result['hasNextPage'];

      final List<GiftCardTransaction> cardTransactions = allTransactions
          .where((t) => t.code == currentCode)
          .toList();

      final uniqueFilteredIds = cardTransactions.map((t) => t.id).toSet().length;

      setState(() {
        List<GiftCardTransaction> updatedTransactions;
        if (shouldRefresh) {
          updatedTransactions = cardTransactions;
        } else {
          // ✅ FIX: Merge + dedup
          final tempList = [..._transactions, ...cardTransactions];
          updatedTransactions = _dedupTransactions(tempList);  // Dedup helper (xem dưới)
        }
        _transactions = updatedTransactions;

        _hasMore = hasNextPage;
        if (!shouldRefresh) _page++;  // ✅ Chỉ ++ nếu load more
        _isLoadingTransactions = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('❌ [_loadTransactions] ERROR: $e');
      if (!mounted) return;

      setState(() {
        _isLoadingTransactions = false;
        _isLoadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading transactions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // ✅ FIX: Unlock global flag luôn (an toàn)
      _isLoadingTransactionsGlobal = false;
    }
  }

// ✅ Helper dedup (thêm method này vào class state)
  List<GiftCardTransaction> _dedupTransactions(List<GiftCardTransaction> txns) {
    final seen = <int>{};  // Dùng id unique
    return txns.where((t) {
      final txnId = t.id;  // Giả sử có id (int/long)
      if (seen.contains(txnId)) return false;
      seen.add(txnId);
      return true;
    }).toList();
  }

  void _onCardChanged(int index) {
    setState(() {
      _currentCardIndex = index;
    });
    _loadTransactions(isRefresh: true);
  }

  Future<void> _refreshData() async {
    await _loadGiftCards();
    if (_giftCards.isNotEmpty) {
      await _loadTransactions(isRefresh: true);
    }
  }

  // ✅ NEW: Show QR Code Dialog - RESPONSIVE for all devices
  void _showQRCodeDialog(UserGiftCard giftCard) {
    // ✅ Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // ✅ Calculate responsive sizes
    // QR: 70% of screen width, max 80% of usable height
    final dialogPadding = 48.0; // 24 * 2
    final availableWidth = screenWidth - dialogPadding - 32; // margins
    final qrSize = (availableWidth * 0.85).clamp(200.0, 500.0); // Min 200, Max 500

    // Responsive font sizes
    final titleSize = screenWidth > 600 ? 24.0 : 20.0;
    final cardNumberSize = screenWidth > 600 ? 22.0 : 18.0;
    final balanceSize = screenWidth > 600 ? 28.0 : 24.0;
    final instructionSize = screenWidth > 600 ? 14.0 : 12.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600, // Max width for tablets
            maxHeight: screenHeight * 0.9, // Max 90% of screen height
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        iconSize: screenWidth > 600 ? 28 : 24,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  SizedBox(height: screenWidth > 600 ? 24 : 16),

                  // ✅ QR Code (RESPONSIVE)
                  Container(
                    padding: EdgeInsets.all(screenWidth > 600 ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: screenWidth > 600 ? 3 : 2,
                      ),
                    ),
                    child: QrImageView(
                      data: giftCard.code,
                      version: QrVersions.auto,
                      size: qrSize, // ✅ Responsive size
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),

                  SizedBox(height: screenWidth > 600 ? 24 : 16),

                  // Card Info
                  Container(
                    padding: EdgeInsets.all(screenWidth > 600 ? 20 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Card Number
                        Text(
                          _formatCardNumber(giftCard.code),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: cardNumberSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),

                        SizedBox(height: screenWidth > 600 ? 16 : 12),

                        // Balance & Owner
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'BALANCE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: screenWidth > 600 ? 12.0 : 10.0,
                                  ),
                                ),
                                SizedBox(height: screenWidth > 600 ? 6 : 4),
                                Text(
                                  '\$${giftCard.remainingBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: balanceSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: screenWidth > 600 ? 50 : 40,
                              width: 1,
                              color: Colors.white30,
                            ),
                            Column(
                              children: [
                                Text(
                                  'OWNER',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: screenWidth > 600 ? 12.0 : 10.0,
                                  ),
                                ),
                                SizedBox(height: screenWidth > 600 ? 6 : 4),
                                Text(
                                  giftCard.ownerName.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth > 600 ? 16.0 : 14.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenWidth > 600 ? 20 : 16),

                  // Instruction
                  Text(
                    'Show this QR code to cashier for payment',
                    style: TextStyle(
                      fontSize: instructionSize,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Gift Card & Transactions",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        iconTheme: IconThemeData(color: AppColors.whiteColor),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Transform.scale(
            scale: 0.5,
            child: SvgPicture.asset(
              'assets/icon/back-button.svg',
              colorFilter: ColorFilter.mode(
                AppColors.blackColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoadingCards
            ? const Center(child: CircularProgressIndicator())
            : _giftCards.isEmpty
            ? _buildEmptyState()
            : Column(
          children: [
            _buildCardStack(),
            if (_giftCards.length > 1) _buildPageIndicator(),
            Divider(
              color: Colors.grey.shade400,
              thickness: 2,
              height: 30,
              indent: 40,
              endIndent: 40,
            ),
            Expanded(
              child: _isLoadingTransactions
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTransactionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.card_giftcard, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Bạn chưa có gift card nào',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Kéo xuống để làm mới',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardStack() {
    return SizedBox(
      height: 260,
      child: PageView.builder(
        controller: _cardPageController,
        onPageChanged: _onCardChanged,
        itemCount: _giftCards.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildGiftCard(_giftCards[index]),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_giftCards.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentCardIndex == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentCardIndex == index
                  ? Colors.purple
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ✅ UPDATED: Added GestureDetector to show QR dialog on tap
  Widget _buildGiftCard(UserGiftCard giftCard) {
    return GestureDetector(
      onTap: () => _showQRCodeDialog(giftCard), // ✅ Tap to show QR
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gift Card',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatCardNumber(giftCard.code),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'OWNER',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        giftCard.ownerName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BALANCE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$ ${giftCard.remainingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            QrImageView(
              data: giftCard.code,
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(
            child: Text(
              'No transactions yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    Map<String, List<GiftCardTransaction>> groupedTransactions = {};
    for (var transaction in _transactions) {
      String dateKey = DateFormat('dd MMM yyyy').format(transaction.transactionDate);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: groupedTransactions.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groupedTransactions.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        String dateKey = groupedTransactions.keys.elementAt(index);
        List<GiftCardTransaction> dayTransactions = groupedTransactions[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8, top: index == 0 ? 0 : 16),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
            ...dayTransactions.map((transaction) => _buildTransactionCard(transaction)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(GiftCardTransaction transaction) {
    Color typeColor;
    IconData typeIcon;
    String amountPrefix;

    switch (transaction.type) {
      case 'CREATE':
        typeColor = Colors.green;
        typeIcon = Icons.add_circle;
        amountPrefix = '+';
        break;
      case 'TOPUP':
        typeColor = Colors.blue;
        typeIcon = Icons.arrow_upward;
        amountPrefix = '+';
        break;
      case 'USAGE':
        typeColor = Colors.red;
        typeIcon = Icons.arrow_downward;
        amountPrefix = '-';
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help_outline;
        amountPrefix = '';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        border: Border.all(color: AppColors.blackColor.withOpacity(0.1), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('hh:mm a').format(transaction.transactionDate),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (transaction.paymentMethod != null)
                  Text(
                    transaction.paymentMethodText,
                    style: TextStyle(
                      color: Colors.purple.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix\$${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Balance: \$${transaction.balanceAfter.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCardNumber(String code) {
    if (code.length == 12) {
      return '${code.substring(0, 4)} ${code.substring(4, 8)} ${code.substring(8, 12)}';
    }
    return code;
  }
}