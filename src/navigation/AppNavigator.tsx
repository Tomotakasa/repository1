import { Ionicons } from '@expo/vector-icons';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import React from 'react';
import { StyleSheet, View } from 'react-native';
import { useApp } from '../store/AppContext';
import CircularScreen from '../screens/CircularScreen';
import EventsScreen from '../screens/EventsScreen';
import FeesScreen from '../screens/FeesScreen';
import HomeScreen from '../screens/HomeScreen';
import ResidentsScreen from '../screens/ResidentsScreen';
import SettingsScreen from '../screens/SettingsScreen';
import { Colors, FontSize } from '../utils/theme';

const Tab = createBottomTabNavigator();
const HomeStack = createStackNavigator();

function HomeStackNavigator() {
  return (
    <HomeStack.Navigator screenOptions={{ headerShown: false }}>
      <HomeStack.Screen name="HomeMain" component={HomeScreen} />
      <HomeStack.Screen name="Settings" component={SettingsScreen} />
    </HomeStack.Navigator>
  );
}

export default function AppNavigator() {
  const { state } = useApp();
  const unreadCount = state.notices.filter((n) => !n.isRead).length;
  const activeCircularsCount = state.circulars.filter((c) => c.status === 'active').length;
  const unpaidCount = state.fees
    .filter((f) => f.status === 'open')
    .reduce((sum, f) => sum + f.payments.filter((p) => !p.paid).length, 0);

  return (
    <NavigationContainer>
      <Tab.Navigator
        screenOptions={({ route }) => ({
          headerShown: false,
          tabBarStyle: styles.tabBar,
          tabBarActiveTintColor: Colors.primary,
          tabBarInactiveTintColor: Colors.textSecondary,
          tabBarLabelStyle: styles.tabLabel,
          tabBarIcon: ({ color, size, focused }) => {
            const icons: Record<string, { active: string; inactive: string }> = {
              Home: { active: 'home', inactive: 'home-outline' },
              Residents: { active: 'people', inactive: 'people-outline' },
              Circular: { active: 'document-text', inactive: 'document-text-outline' },
              Fees: { active: 'cash', inactive: 'cash-outline' },
              Events: { active: 'calendar', inactive: 'calendar-outline' },
            };
            const iconName = focused
              ? icons[route.name]?.active
              : icons[route.name]?.inactive;
            return (
              <Ionicons name={iconName as any} size={focused ? size + 2 : size} color={color} />
            );
          },
        })}
      >
        <Tab.Screen
          name="Home"
          component={HomeStackNavigator}
          options={{
            tabBarLabel: 'ホーム',
            tabBarBadge: unreadCount > 0 ? unreadCount : undefined,
            tabBarBadgeStyle: styles.badge,
          }}
        />
        <Tab.Screen
          name="Residents"
          component={ResidentsScreen}
          options={{ tabBarLabel: '住民名簿' }}
        />
        <Tab.Screen
          name="Circular"
          component={CircularScreen}
          options={{
            tabBarLabel: '回覧板',
            tabBarBadge: activeCircularsCount > 0 ? activeCircularsCount : undefined,
            tabBarBadgeStyle: styles.badge,
          }}
        />
        <Tab.Screen
          name="Fees"
          component={FeesScreen}
          options={{
            tabBarLabel: '集金',
            tabBarBadge: unpaidCount > 0 ? unpaidCount : undefined,
            tabBarBadgeStyle: styles.badge,
          }}
        />
        <Tab.Screen
          name="Events"
          component={EventsScreen}
          options={{ tabBarLabel: '行事' }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: Colors.surface,
    borderTopColor: Colors.border,
    borderTopWidth: 1,
    paddingTop: 6,
    height: 80,
    paddingBottom: 8,
  },
  tabLabel: {
    fontSize: FontSize.xs,
    fontWeight: '600',
    marginTop: 2,
  },
  badge: {
    backgroundColor: Colors.error,
    fontSize: 10,
    minWidth: 16,
    height: 16,
  },
});
