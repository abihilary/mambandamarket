import 'package:flutter/material.dart';

class SearchHeader extends StatefulWidget {
  final String locationText;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotificationTap;

  const SearchHeader({
    Key? key,
    this.locationText = "Aalen (+25 km)",
    this.onSearchSubmitted,
    this.onSearchChanged,
    this.onLocationTap,
    this.onNotificationTap,
  }) : super(key: key);

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Search Input Container
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.black54, size: 20),
                  const SizedBox(width: 8),

                  // Real TextField for typing input
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: widget.onSearchChanged,
                      onSubmitted: widget.onSearchSubmitted,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Suche in ${widget.locationText}",
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          overflow: TextOverflow.ellipsis,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // Clear button when user types something
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                        });
                        widget.onSearchChanged?.call("");
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(Icons.close, size: 18, color: Colors.grey),
                      ),
                    ),

                  // Location Tag Button
                  GestureDetector(
                    onTap: widget.onLocationTap,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0, left: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.indigo,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell Button
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: Colors.black87,
              size: 26,
            ),
            onPressed: widget.onNotificationTap,
          ),
        ],
      ),
    );
  }
}