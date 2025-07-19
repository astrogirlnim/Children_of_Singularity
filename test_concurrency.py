#!/usr/bin/env python3
"""
Concurrency Test for Children of the Singularity Trading API
Tests race conditions and validates our S3 ETag optimistic locking
"""

import asyncio
import aiohttp
import json
import time
import uuid
from typing import List, Dict, Any

# Configuration
API_BASE_URL = "https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod"
LISTINGS_ENDPOINT = "/listings"

async def create_test_listing(session: aiohttp.ClientSession, item_name: str, price: int) -> str:
    """Create a test listing and return the listing ID"""
    listing_data = {
        "seller_id": f"test_seller_{uuid.uuid4().hex[:8]}",
        "seller_name": "Test Seller",
        "item_type": "debris",
        "item_name": item_name,
        "quantity": 1,
        "asking_price": price,
        "description": "Test item for concurrency testing"
    }

    async with session.post(API_BASE_URL + LISTINGS_ENDPOINT, json=listing_data) as response:
        data = await response.json()
        if data.get("success") and "listing" in data:
            return data["listing"]["listing_id"]
        else:
            raise Exception(f"Failed to create listing: {data}")

async def attempt_purchase(session: aiohttp.ClientSession, listing_id: str, buyer_id: str, expected_price: int) -> Dict[str, Any]:
    """Attempt to purchase an item"""
    purchase_data = {
        "buyer_id": buyer_id,
        "buyer_name": f"Buyer {buyer_id}",
        "expected_price": expected_price
    }

    url = f"{API_BASE_URL}{LISTINGS_ENDPOINT}/{listing_id}/buy"
    start_time = time.time()

    try:
        async with session.post(url, json=purchase_data) as response:
            data = await response.json()
            end_time = time.time()

            return {
                "buyer_id": buyer_id,
                "success": data.get("success", False),
                "response": data,
                "duration": end_time - start_time,
                "status_code": response.status
            }
    except Exception as e:
        return {
            "buyer_id": buyer_id,
            "success": False,
            "error": str(e),
            "duration": time.time() - start_time
        }

async def test_concurrent_purchases():
    """Test concurrent purchase attempts on the same item"""
    print("🧪 Testing Concurrent Purchase Protection")
    print("=" * 50)

    async with aiohttp.ClientSession() as session:
        # Create a test listing
        test_item_name = f"test_item_{uuid.uuid4().hex[:8]}"
        test_price = 100

        print(f"Creating test listing: {test_item_name} for {test_price} credits")
        listing_id = await create_test_listing(session, test_item_name, test_price)
        print(f"✅ Created listing: {listing_id}")

        # Simulate 10 concurrent purchase attempts
        print(f"\n🚀 Launching 10 concurrent purchase attempts...")
        tasks = []
        for i in range(10):
            buyer_id = f"buyer_{i:02d}"
            task = attempt_purchase(session, listing_id, buyer_id, test_price)
            tasks.append(task)

        # Execute all purchases simultaneously
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Analyze results
        print(f"\n📊 Results Analysis")
        print("-" * 30)

        successful_purchases = []
        failed_purchases = []
        errors = []

        for result in results:
            if isinstance(result, Exception):
                errors.append(str(result))
            elif result.get("success", False):
                successful_purchases.append(result)
            else:
                failed_purchases.append(result)

        print(f"✅ Successful purchases: {len(successful_purchases)}")
        print(f"❌ Failed purchases: {len(failed_purchases)}")
        print(f"💥 Errors: {len(errors)}")

        # Check for race condition
        if len(successful_purchases) > 1:
            print(f"\n🚨 RACE CONDITION DETECTED!")
            print(f"Multiple buyers successfully purchased the same item:")
            for purchase in successful_purchases:
                print(f"  - Buyer {purchase['buyer_id']}: {purchase['response']}")
            return False
        elif len(successful_purchases) == 1:
            print(f"\n✅ CONCURRENCY PROTECTION WORKING!")
            winner = successful_purchases[0]
            print(f"  - Winner: Buyer {winner['buyer_id']}")
            print(f"  - Purchase time: {winner['duration']:.2f}s")

            # Show failure reasons
            print(f"\n📋 Failure reasons:")
            failure_reasons = {}
            for failure in failed_purchases:
                reason = failure.get("response", {}).get("error", "Unknown error")
                failure_reasons[reason] = failure_reasons.get(reason, 0) + 1

            for reason, count in failure_reasons.items():
                print(f"  - {reason}: {count} buyers")

            return True
        else:
            print(f"\n⚠️ NO SUCCESSFUL PURCHASES - All failed")
            return False

async def test_rapid_listing_creation():
    """Test rapid listing creation to check for race conditions"""
    print("\n🧪 Testing Rapid Listing Creation")
    print("=" * 50)

    async with aiohttp.ClientSession() as session:
        # Create 20 listings simultaneously
        print("🚀 Creating 20 listings simultaneously...")

        tasks = []
        for i in range(20):
            item_name = f"rapid_test_item_{i:02d}"
            price = 50 + i
            task = create_test_listing(session, item_name, price)
            tasks.append(task)

        # Execute all creations simultaneously
        start_time = time.time()
        results = await asyncio.gather(*tasks, return_exceptions=True)
        end_time = time.time()

        # Analyze results
        successful_creations = []
        failed_creations = []

        for result in results:
            if isinstance(result, Exception):
                failed_creations.append(str(result))
            else:
                successful_creations.append(result)

        print(f"\n📊 Creation Results")
        print(f"✅ Successful: {len(successful_creations)}")
        print(f"❌ Failed: {len(failed_creations)}")
        print(f"⏱️ Total time: {end_time - start_time:.2f}s")
        print(f"📈 Rate: {len(successful_creations) / (end_time - start_time):.1f} listings/sec")

        if failed_creations:
            print(f"\n💥 Creation failures:")
            for error in failed_creations[:3]:  # Show first 3 errors
                print(f"  - {error}")

        return len(successful_creations) >= 15  # Allow some failures due to network

async def test_price_validation():
    """Test price validation prevents race conditions"""
    print("\n🧪 Testing Price Validation Protection")
    print("=" * 50)

    async with aiohttp.ClientSession() as session:
        # Create a test listing
        test_item_name = f"price_test_{uuid.uuid4().hex[:8]}"
        correct_price = 200
        wrong_price = 150

        print(f"Creating test listing: {test_item_name} for {correct_price} credits")
        listing_id = await create_test_listing(session, test_item_name, correct_price)
        print(f"✅ Created listing: {listing_id}")

        # Test purchase with wrong price expectation
        print(f"\n🚀 Attempting purchase with wrong expected price ({wrong_price})")
        result = await attempt_purchase(session, listing_id, "price_test_buyer", wrong_price)

        if result.get("success", False):
            print(f"❌ PRICE VALIDATION FAILED - Purchase succeeded with wrong price")
            return False
        else:
            error_msg = result.get("response", {}).get("error", "")
            if "Price changed" in error_msg:
                print(f"✅ PRICE VALIDATION WORKING - Correctly rejected wrong price")
                print(f"  Error: {error_msg}")
                return True
            else:
                print(f"⚠️ Purchase failed but not due to price validation: {error_msg}")
                return False

async def main():
    """Run all concurrency tests"""
    print("🔒 Children of the Singularity - Concurrency Tests")
    print("=" * 60)

    test_results = []

    # Test 1: Concurrent purchase protection
    try:
        result1 = await test_concurrent_purchases()
        test_results.append(("Concurrent Purchase Protection", result1))
    except Exception as e:
        print(f"💥 Concurrent purchase test failed: {e}")
        test_results.append(("Concurrent Purchase Protection", False))

    # Test 2: Rapid listing creation
    try:
        result2 = await test_rapid_listing_creation()
        test_results.append(("Rapid Listing Creation", result2))
    except Exception as e:
        print(f"💥 Rapid listing test failed: {e}")
        test_results.append(("Rapid Listing Creation", False))

    # Test 3: Price validation
    try:
        result3 = await test_price_validation()
        test_results.append(("Price Validation Protection", result3))
    except Exception as e:
        print(f"💥 Price validation test failed: {e}")
        test_results.append(("Price Validation Protection", False))

    # Summary
    print(f"\n🎯 Test Summary")
    print("=" * 60)

    passed = 0
    total = len(test_results)

    for test_name, passed_test in test_results:
        status = "✅ PASS" if passed_test else "❌ FAIL"
        print(f"{status} {test_name}")
        if passed_test:
            passed += 1

    print(f"\n📊 Overall Result: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 ALL CONCURRENCY TESTS PASSED!")
        print("Your trading marketplace is protected against race conditions.")
    else:
        print("⚠️ Some tests failed - review concurrency protection.")

    return passed == total

if __name__ == "__main__":
    asyncio.run(main())
