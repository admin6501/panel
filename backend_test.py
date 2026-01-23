#!/usr/bin/env python3
import requests
import sys
import json
from datetime import datetime

class V2RayBotAPITester:
    def __init__(self, base_url="https://tunnelforge.preview.emergentagent.com"):
        self.base_url = base_url
        self.token = None
        self.tests_run = 0
        self.tests_passed = 0
        self.failed_tests = []

    def run_test(self, name, method, endpoint, expected_status, data=None, auth_required=True):
        """Run a single API test"""
        url = f"{self.base_url}/api/{endpoint}"
        headers = {'Content-Type': 'application/json'}
        if auth_required and self.token:
            headers['Authorization'] = f'Bearer {self.token}'

        self.tests_run += 1
        print(f"\n🔍 Testing {name}...")
        print(f"   URL: {method} {url}")
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, timeout=10)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=headers, timeout=10)
            elif method == 'PUT':
                response = requests.put(url, json=data, headers=headers, timeout=10)
            elif method == 'DELETE':
                response = requests.delete(url, headers=headers, timeout=10)

            success = response.status_code == expected_status
            if success:
                self.tests_passed += 1
                print(f"✅ Passed - Status: {response.status_code}")
                try:
                    return True, response.json() if response.content else {}
                except:
                    return True, {}
            else:
                print(f"❌ Failed - Expected {expected_status}, got {response.status_code}")
                print(f"   Response: {response.text[:200]}...")
                self.failed_tests.append({
                    "test": name,
                    "expected": expected_status,
                    "actual": response.status_code,
                    "response": response.text[:200]
                })
                return False, {}

        except Exception as e:
            print(f"❌ Failed - Error: {str(e)}")
            self.failed_tests.append({
                "test": name,
                "error": str(e)
            })
            return False, {}

    def test_health_check(self):
        """Test health endpoint"""
        return self.run_test("Health Check", "GET", "health", 200, auth_required=False)

    def test_login(self):
        """Test login with admin/admin credentials"""
        success, response = self.run_test(
            "Admin Login",
            "POST",
            "auth/login",
            200,
            data={"username": "admin", "password": "admin"},
            auth_required=False
        )
        if success and 'access_token' in response:
            self.token = response['access_token']
            print(f"   Token obtained: {self.token[:20]}...")
            return True
        return False

    def test_get_me(self):
        """Test get current user info"""
        return self.run_test("Get Current User", "GET", "auth/me", 200)

    def test_dashboard_stats(self):
        """Test dashboard statistics"""
        return self.run_test("Dashboard Stats", "GET", "dashboard/stats", 200)

    def test_dashboard_chart(self):
        """Test dashboard chart data"""
        return self.run_test("Dashboard Chart", "GET", "dashboard/chart?days=7", 200)

    def test_servers_crud(self):
        """Test servers CRUD operations"""
        print("\n📋 Testing Servers CRUD...")
        
        # Get servers
        success, servers = self.run_test("Get Servers", "GET", "servers", 200)
        if not success:
            return False

        # Create server
        server_data = {
            "name": "Test Server",
            "panel_url": "https://test.example.com",
            "panel_username": "testuser",
            "panel_password": "testpass",
            "is_active": True,
            "max_users": 100,
            "description": "Test server for API testing"
        }
        success, created_server = self.run_test("Create Server", "POST", "servers", 200, server_data)
        if not success:
            return False

        server_id = created_server.get('id')
        if not server_id:
            print("❌ No server ID returned from create")
            return False

        # Update server
        update_data = {"name": "Updated Test Server", "description": "Updated description"}
        success, _ = self.run_test("Update Server", "PUT", f"servers/{server_id}", 200, update_data)
        if not success:
            return False

        # Test server connection (will fail but should return proper response)
        success, _ = self.run_test("Test Server Connection", "POST", f"servers/{server_id}/test", 200)

        # Delete server
        success, _ = self.run_test("Delete Server", "DELETE", f"servers/{server_id}", 200)
        return success

    def test_categories_crud(self):
        """Test categories CRUD operations"""
        print("\n📋 Testing Categories CRUD...")
        
        # Get categories
        success, categories = self.run_test("Get Categories", "GET", "categories", 200)
        if not success:
            return False

        # Create category
        category_data = {
            "name": "Test Category",
            "description": "Test category for API testing",
            "icon": "📦",
            "color": "#3b82f6",
            "is_active": True,
            "sort_order": 0
        }
        success, created_category = self.run_test("Create Category", "POST", "categories", 200, category_data)
        if not success:
            return False

        category_id = created_category.get('id')
        if not category_id:
            print("❌ No category ID returned from create")
            return False

        # Update category
        update_data = {"name": "Updated Test Category", "color": "#ef4444"}
        success, _ = self.run_test("Update Category", "PUT", f"categories/{category_id}", 200, update_data)
        if not success:
            return False

        # Test category deletion (will be done after plan tests)
        return True, category_id

    def test_plans_crud(self):
        """Test plans CRUD operations including unlimited features"""
        print("\n📋 Testing Plans CRUD...")
        
        # First create a test category
        category_success, category_id = self.test_categories_crud()
        if not category_success:
            return False

        # Get plans
        success, plans = self.run_test("Get Plans", "GET", "plans", 200)
        if not success:
            return False

        # Test filtering plans by category
        success, filtered_plans = self.run_test("Get Plans by Category", "GET", f"plans?category_id={category_id}", 200)
        if not success:
            return False

        # Create regular plan with category
        plan_data = {
            "name": "Test Plan",
            "description": "Test plan for API testing",
            "category_id": category_id,
            "price": 50000,
            "duration_days": 30,
            "traffic_gb": 100,
            "user_limit": 1,
            "server_ids": [],
            "is_active": True,
            "is_test": True,
            "sort_order": 0
        }
        success, created_plan = self.run_test("Create Plan with Category", "POST", "plans", 200, plan_data)
        if not success:
            return False

        plan_id = created_plan.get('id')
        if not plan_id:
            print("❌ No plan ID returned from create")
            return False

        # Create unlimited duration plan
        unlimited_duration_data = {
            "name": "Unlimited Duration Plan",
            "description": "Plan with unlimited duration",
            "category_id": category_id,
            "price": 100000,
            "duration_days": None,  # Unlimited duration
            "traffic_gb": 50,
            "user_limit": 1,
            "server_ids": [],
            "is_active": True,
            "is_test": True,
            "sort_order": 1
        }
        success, unlimited_duration_plan = self.run_test("Create Unlimited Duration Plan", "POST", "plans", 200, unlimited_duration_data)
        if not success:
            return False

        unlimited_duration_id = unlimited_duration_plan.get('id')

        # Create unlimited traffic plan
        unlimited_traffic_data = {
            "name": "Unlimited Traffic Plan",
            "description": "Plan with unlimited traffic",
            "category_id": category_id,
            "price": 150000,
            "duration_days": 30,
            "traffic_gb": None,  # Unlimited traffic
            "user_limit": 1,
            "server_ids": [],
            "is_active": True,
            "is_test": True,
            "sort_order": 2
        }
        success, unlimited_traffic_plan = self.run_test("Create Unlimited Traffic Plan", "POST", "plans", 200, unlimited_traffic_data)
        if not success:
            return False

        unlimited_traffic_id = unlimited_traffic_plan.get('id')

        # Create fully unlimited plan
        fully_unlimited_data = {
            "name": "Fully Unlimited Plan",
            "description": "Plan with unlimited duration and traffic",
            "category_id": category_id,
            "price": 200000,
            "duration_days": None,  # Unlimited duration
            "traffic_gb": None,     # Unlimited traffic
            "user_limit": 1,
            "server_ids": [],
            "is_active": True,
            "is_test": True,
            "sort_order": 3
        }
        success, fully_unlimited_plan = self.run_test("Create Fully Unlimited Plan", "POST", "plans", 200, fully_unlimited_data)
        if not success:
            return False

        fully_unlimited_id = fully_unlimited_plan.get('id')

        # Update plan
        update_data = {"name": "Updated Test Plan", "price": 60000}
        success, _ = self.run_test("Update Plan", "PUT", f"plans/{plan_id}", 200, update_data)
        if not success:
            return False

        # Verify unlimited plans were created correctly
        success, plan_details = self.run_test("Get Updated Plan", "GET", f"plans", 200)
        if success:
            print("   ✅ Verifying unlimited plan features...")
            for plan in plan_details:
                if plan['id'] == unlimited_duration_id and plan['duration_days'] is None:
                    print("   ✅ Unlimited duration plan created correctly")
                elif plan['id'] == unlimited_traffic_id and plan['traffic_gb'] is None:
                    print("   ✅ Unlimited traffic plan created correctly")
                elif plan['id'] == fully_unlimited_id and plan['duration_days'] is None and plan['traffic_gb'] is None:
                    print("   ✅ Fully unlimited plan created correctly")

        # Delete plans
        success, _ = self.run_test("Delete Plan", "DELETE", f"plans/{plan_id}", 200)
        if success:
            self.run_test("Delete Unlimited Duration Plan", "DELETE", f"plans/{unlimited_duration_id}", 200)
            self.run_test("Delete Unlimited Traffic Plan", "DELETE", f"plans/{unlimited_traffic_id}", 200)
            self.run_test("Delete Fully Unlimited Plan", "DELETE", f"plans/{fully_unlimited_id}", 200)

        # Delete test category
        success, _ = self.run_test("Delete Test Category", "DELETE", f"categories/{category_id}", 200)
        
        return success

    def test_orders_and_payments(self):
        """Test orders and payments listing"""
        print("\n📋 Testing Orders and Payments...")
        
        # Get orders
        success, _ = self.run_test("Get Orders", "GET", "orders", 200)
        if not success:
            return False

        # Get payments
        success, _ = self.run_test("Get Payments", "GET", "payments", 200)
        return success

    def test_discount_codes_crud(self):
        """Test discount codes CRUD operations"""
        print("\n📋 Testing Discount Codes CRUD...")
        
        # Get discount codes
        success, codes = self.run_test("Get Discount Codes", "GET", "discount-codes", 200)
        if not success:
            return False

        # Create discount code
        code_data = {
            "code": "TEST50",
            "discount_percent": 50,
            "max_uses": 10,
            "is_active": True,
            "plan_ids": []
        }
        success, created_code = self.run_test("Create Discount Code", "POST", "discount-codes", 200, code_data)
        if not success:
            return False

        code_id = created_code.get('id')
        if not code_id:
            print("❌ No code ID returned from create")
            return False

        # Update discount code
        update_data = {"discount_percent": 30}
        success, _ = self.run_test("Update Discount Code", "PUT", f"discount-codes/{code_id}", 200, update_data)
        if not success:
            return False

        # Delete discount code
        success, _ = self.run_test("Delete Discount Code", "DELETE", f"discount-codes/{code_id}", 200)
        return success

    def test_departments_and_tickets(self):
        """Test departments and tickets"""
        print("\n📋 Testing Departments and Tickets...")
        
        # Get departments
        success, departments = self.run_test("Get Departments", "GET", "departments", 200)
        if not success:
            return False

        # Get tickets
        success, _ = self.run_test("Get Tickets", "GET", "tickets", 200)
        return success

    def test_resellers_crud(self):
        """Test resellers CRUD operations"""
        print("\n📋 Testing Resellers CRUD...")
        
        # Get resellers
        success, resellers = self.run_test("Get Resellers", "GET", "resellers", 200)
        if not success:
            return False

        # Note: Creating reseller requires existing telegram user, so we'll skip create/update/delete
        print("   ℹ️  Skipping reseller CRUD as it requires existing telegram users")
        return True

    def test_users_management(self):
        """Test users management"""
        print("\n📋 Testing Users Management...")
        
        # Get telegram users
        success, _ = self.run_test("Get Telegram Users", "GET", "users", 200)
        return success

    def test_settings(self):
        """Test settings"""
        print("\n📋 Testing Settings...")
        
        # Get settings
        success, settings = self.run_test("Get Settings", "GET", "settings", 200)
        if not success:
            return False

        # Update settings (minimal update to avoid breaking bot config)
        if settings:
            update_data = {"payment_timeout_minutes": 30}
            success, _ = self.run_test("Update Settings", "PUT", "settings", 200, update_data)
        
        return success

    def test_subscriptions(self):
        """Test subscriptions"""
        print("\n📋 Testing Subscriptions...")
        
        # Get subscriptions
        success, _ = self.run_test("Get Subscriptions", "GET", "subscriptions", 200)
        return success

    def run_all_tests(self):
        """Run all API tests"""
        print("🚀 Starting V2Ray Bot API Tests...")
        print(f"   Base URL: {self.base_url}")
        
        # Health check first
        if not self.test_health_check()[0]:
            print("❌ Health check failed, stopping tests")
            return False

        # Login is required for all other tests
        if not self.test_login():
            print("❌ Login failed, stopping tests")
            return False

        # Test user info
        self.test_get_me()

        # Test dashboard
        self.test_dashboard_stats()
        self.test_dashboard_chart()

        # Test CRUD operations
        self.test_servers_crud()
        self.test_plans_crud()  # This now includes categories testing
        self.test_discount_codes_crud()

        # Test listing endpoints
        self.test_orders_and_payments()
        self.test_departments_and_tickets()
        self.test_resellers_crud()
        self.test_users_management()
        self.test_subscriptions()

        # Test settings
        self.test_settings()

        return True

    def print_summary(self):
        """Print test summary"""
        print(f"\n📊 Test Summary:")
        print(f"   Tests run: {self.tests_run}")
        print(f"   Tests passed: {self.tests_passed}")
        print(f"   Tests failed: {self.tests_run - self.tests_passed}")
        print(f"   Success rate: {(self.tests_passed/self.tests_run*100):.1f}%")
        
        if self.failed_tests:
            print(f"\n❌ Failed Tests:")
            for test in self.failed_tests:
                error_msg = test.get('error', f"Expected {test.get('expected')}, got {test.get('actual')}")
                print(f"   - {test['test']}: {error_msg}")

def main():
    tester = V2RayBotAPITester()
    
    try:
        tester.run_all_tests()
    except KeyboardInterrupt:
        print("\n⚠️  Tests interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
    finally:
        tester.print_summary()
    
    # Return exit code based on success rate
    success_rate = (tester.tests_passed / tester.tests_run * 100) if tester.tests_run > 0 else 0
    return 0 if success_rate >= 80 else 1

if __name__ == "__main__":
    sys.exit(main())