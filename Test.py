# weight =  200
# height = 1.85
# bmi = weight/(height **2 )

# if bmi <= 18.5:
#     print("Underweight")
# elif bmi > 18.5 and bmi <= 24.9:
#     print("Normal")
# else:
#     print ("Overweight")

small = 15
medium = 20
large = 25
cost = 0

size = input("Welcome to Python Pizza Deliveries! \n What Size Pizza do you want? S, M, L?:   ")
pquestion = input("Would you like Pepperoni on your Pizza? Y or N:  ")
xcheesequestion = input("Would you like extra cheese? Y or N:  ")

if size == "S":
    cost = small
elif size == "M":
    cost = medium
elif size == "L":
    cost = large
else:
    print("Must enter S, M, or L")

if pquestion == "Y":
    if size =="S":
        cost += 2
    else:
        cost += 3

if xcheesequestion == "Y":
    cost += 1

print(f"Your Final Bill is:  ${cost} ")

##