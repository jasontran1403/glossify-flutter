import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Chart Placeholders - Empty state charts
class ChartPlaceholders {

  /// Placeholder for Line Chart (Sales)
  static Widget lineChart({required double Function(double) scale}) {
    return Stack(
      children: [
        LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 0.5,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) {
                    final days = ['Su', 'M', 'Tu', 'W', 'T', 'F', 'Sa'];
                    final index = value.toInt();
                    if (index < 0 || index >= days.length) return const Text('');
                    return Text(
                      days[index],
                      style: TextStyle(
                        fontSize: scale(8),
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 20,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '\$${value.toInt()}',
                      style: TextStyle(
                        fontSize: scale(7),
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 6,
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: [
                  FlSpot(0, 10),
                  FlSpot(1, 20),
                  FlSpot(2, 15),
                  FlSpot(3, 30),
                  FlSpot(4, 25),
                  FlSpot(5, 35),
                  FlSpot(6, 30),
                ],
                isCurved: true,
                color: Colors.grey.shade300,
                barWidth: scale(2),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: scale(2),
                      color: Colors.grey.shade300,
                      strokeWidth: scale(1),
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.grey.shade200.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No data available',
              style: TextStyle(
                fontSize: scale(11),
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Placeholder for Pie Chart (Payment Breakdown)
  static Widget pieChart({required double Function(double) scale}) {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 20,
                  sections: [
                    PieChartSectionData(
                      color: Colors.grey.shade300,
                      value: 33.33,
                      title: '0%',
                      radius: scale(30),
                      titleStyle: TextStyle(
                        fontSize: scale(10),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.grey.shade200,
                      value: 33.33,
                      title: '0%',
                      radius: scale(30),
                      titleStyle: TextStyle(
                        fontSize: scale(10),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.grey.shade100,
                      value: 33.34,
                      title: '0%',
                      radius: scale(30),
                      titleStyle: TextStyle(
                        fontSize: scale(10),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Card', Colors.grey.shade300, 8, scale),
                  const SizedBox(height: 4),
                  _buildLegendItem('Cash', Colors.grey.shade200, 8, scale),
                  const SizedBox(height: 4),
                  _buildLegendItem('Gift Card', Colors.grey.shade100, 8, scale),
                ],
              ),
            ),
          ],
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No data',
              style: TextStyle(
                fontSize: scale(11),
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Placeholder for Bar Chart (Clients Per Day)
  static Widget barChart({required double Function(double) scale}) {
    return Stack(
      children: [
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 50,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final days = ['Su', 'M', 'Tu', 'W', 'T', 'F', 'Sa'];
                    final index = value.toInt();
                    if (index < 0 || index >= days.length) return const Text('');
                    return Padding(
                      padding: EdgeInsets.only(top: scale(4)),
                      child: Text(
                        days[index],
                        style: TextStyle(
                          fontSize: scale(8),
                          color: Colors.grey.shade400,
                        ),
                      ),
                    );
                  },
                  reservedSize: 18,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 10,
                  reservedSize: scale(20),
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: scale(7),
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 10,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 0.5,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(7, (index) {
              final heights = [10.0, 20.0, 15.0, 25.0, 18.0, 30.0, 22.0];
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: heights[index],
                    color: Colors.grey.shade300,
                    width: scale(12),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(scale(3)),
                      topRight: Radius.circular(scale(3)),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No data available',
              style: TextStyle(
                fontSize: scale(11),
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Placeholder for Donut Chart (Clients card)
  static Widget donutChart({required double Function(double) scale}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 20,
            sections: [
              PieChartSectionData(
                color: Colors.grey.shade300,
                value: 50,
                title: '',
                radius: 15,
              ),
              PieChartSectionData(
                color: Colors.grey.shade200,
                value: 50,
                title: '',
                radius: 15,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: Text(
            '0',
            style: TextStyle(
              fontSize: scale(10),
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Helper: Legend item
  static Widget _buildLegendItem(
      String label,
      Color color,
      double size,
      double Function(double) scale,
      ) {
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: scale(4)),
        Text(
          label,
          style: TextStyle(
            fontSize: scale(10),
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}