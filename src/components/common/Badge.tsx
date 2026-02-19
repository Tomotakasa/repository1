import React from 'react';
import { StyleSheet, Text, View, ViewStyle } from 'react-native';
import { BorderRadius, Colors, FontSize, Spacing } from '../../utils/theme';

interface BadgeProps {
  label: string;
  color?: string;
  size?: 'sm' | 'md';
  style?: ViewStyle;
}

export default function Badge({ label, color = Colors.primary, size = 'md', style }: BadgeProps) {
  return (
    <View style={[styles.badge, { backgroundColor: color + '20' }, style]}>
      <Text style={[styles.text, { color, fontSize: size === 'sm' ? FontSize.xs : FontSize.sm }]}>
        {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    borderRadius: BorderRadius.round,
    alignSelf: 'flex-start',
  },
  text: {
    fontWeight: '600',
  },
});
