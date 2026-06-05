from datetime import datetime, timedelta
from typing import Literal

from dateutil.relativedelta import relativedelta


def date_add(
    date: str | datetime,
    amount: int,
    unit: Literal['day', 'week', 'month', 'year']
) -> datetime:
    """
    Add a specified amount of time to a date.
    
    Args:
        date: Input date (datetime object or string)
        amount: Number of units to add (can be negative)
        unit: Time unit to add ('day', 'week', 'month', or 'year')
    
    Returns:
        datetime: New date after addition
        
    Examples:
        >>> date_add('2024-01-01', 1, 'month')
        datetime(2024, 2, 1)
        >>> date_add(datetime(2024, 1, 1), -1, 'week')
        datetime(2023, 12, 25)
    """
    # Convert string to datetime if needed
    if isinstance(date, str):
        try:
            date = datetime.fromisoformat(date.replace('Z', '+00:00'))
        except ValueError as e:
            raise ValueError(f"Invalid date format: {str(e)}")

    if not isinstance(date, datetime):
        raise TypeError("date must be a string or datetime object")

    if not isinstance(amount, int):
        raise TypeError("amount must be an integer")

    if unit not in ['day', 'week', 'month', 'year']:
        raise ValueError("unit must be 'day', 'week', 'month', or 'year'")

    # Handle each unit type
    if unit == 'day':
        return date + timedelta(days=amount)
    elif unit == 'week':
        return date + timedelta(weeks=amount)
    elif unit == 'month':
        return date + relativedelta(months=amount)
    else:  # year
        return date + relativedelta(years=amount)
